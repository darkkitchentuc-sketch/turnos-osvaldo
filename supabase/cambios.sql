-- Turnos Osvaldo: fichar solo con DNI y pedidos de cambio de turno.
-- Correr después de fichadas.sql. Pegar completo en Supabase → SQL Editor → New query → Run. Se puede correr más de una vez.

-- ---------- 1) Fichar solo con DNI (sin PIN) ----------
alter table public.accesos alter column pin_hash drop not null;
drop function if exists public.fichar(text, text, text);
drop function if exists public.set_acceso(text, text, text);

create or replace function public.set_acceso(p_staff text, p_dni text)
returns void language plpgsql security definer set search_path = public as $$
declare d text := regexp_replace(coalesce(p_dni,''), '\D', '', 'g');
begin
  if not public.es_editor() then raise exception 'Solo un editor puede cargar accesos'; end if;
  if length(d) < 6 or length(d) > 9 then raise exception 'El DNI tiene que tener entre 6 y 9 números'; end if;
  if exists (select 1 from public.accesos where dni = d and staff_id <> p_staff) then raise exception 'Ese DNI ya lo tiene otra persona'; end if;
  insert into public.accesos (staff_id, dni) values (p_staff, d)
  on conflict (staff_id) do update set dni = excluded.dni, fallos = 0, bloqueado_hasta = null, updated_at = now();
end $$;

-- p_tipo: 'in' o 'out'. La hora la pone el servidor.
create or replace function public.fichar(p_dni text, p_tipo text)
returns json language plpgsql security definer set search_path = public as $$
declare
  d text := regexp_replace(coalesce(p_dni,''), '\D', '', 'g');
  sid text; ult public.fichadas; nueva timestamptz; dup boolean := false;
begin
  if p_tipo not in ('in','out') then return json_build_object('ok', false, 'error', 'tipo'); end if;
  select staff_id into sid from public.accesos where dni = d;
  if sid is null then perform pg_sleep(0.4); return json_build_object('ok', false, 'error', 'datos'); end if;
  select * into ult from public.fichadas where staff_id = sid order by at desc limit 1;
  -- Un doble toque en menos de 2 minutos no crea otra marca.
  if ult.id is not null and ult.tipo = p_tipo and ult.at > now() - interval '2 minutes' then
    dup := true; nueva := ult.at;
  else
    insert into public.fichadas (staff_id, tipo) values (sid, p_tipo) returning at into nueva;
  end if;
  return json_build_object('ok', true, 'staff_id', sid, 'tipo', p_tipo, 'at', nueva, 'repetida', dup,
    'recientes', (select coalesce(json_agg(json_build_object('tipo', f.tipo, 'at', f.at) order by f.at desc), '[]'::json)
                  from (select tipo, at from public.fichadas where staff_id = sid order by at desc limit 8) f));
end $$;

revoke all on function public.set_acceso(text, text) from public, anon;
grant execute on function public.set_acceso(text, text) to authenticated;
revoke all on function public.fichar(text, text) from public;
grant execute on function public.fichar(text, text) to anon, authenticated;

-- ---------- 2) Pedidos de cambio de turno ----------
create table if not exists public.solicitudes (
  id bigint generated always as identity primary key,
  staff_id text not null,
  tipo text not null check (tipo in ('ceder','cambio','horario')),
  semana text not null,
  assign_id text not null,
  para_staff text,
  para_semana text,
  para_assign_id text,
  nuevo_in text,
  nuevo_out text,
  motivo text,
  resumen text,
  estado text not null default 'pendiente' check (estado in ('pendiente','aprobada','rechazada','cancelada')),
  respuesta text,
  resuelto_por text,
  resuelto_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists solicitudes_staff on public.solicitudes (staff_id, created_at desc);

alter table public.solicitudes enable row level security;
revoke all on public.solicitudes from anon, authenticated;
grant select on public.solicitudes to authenticated;
grant update (estado, respuesta, resuelto_por, resuelto_at) on public.solicitudes to authenticated;
drop policy if exists "editores ven pedidos" on public.solicitudes;
create policy "editores ven pedidos" on public.solicitudes for select to authenticated using (public.es_editor());
drop policy if exists "editores resuelven pedidos" on public.solicitudes;
create policy "editores resuelven pedidos" on public.solicitudes for update to authenticated using (public.es_editor()) with check (public.es_editor());

-- ¿El turno existe en esa semana y es de esa persona?
create or replace function public.turno_de(p_semana text, p_assign text, p_staff text)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.docs, jsonb_array_elements(data -> 'assign') e
                 where path = 'weeks/' || p_semana and e ->> 'id' = p_assign and e ->> 's' = p_staff);
$$;
revoke all on function public.turno_de(text, text, text) from public, anon, authenticated;

-- Una persona pide el cambio con su DNI.
create or replace function public.solicitar_cambio(p_dni text, p_datos jsonb)
returns json language plpgsql security definer set search_path = public as $$
declare
  d text := regexp_replace(coalesce(p_dni,''), '\D', '', 'g');
  sid text; t text := p_datos ->> 'tipo'; sem text := p_datos ->> 'semana'; aid text := p_datos ->> 'assign_id';
  para text := nullif(p_datos ->> 'para_staff', ''); psem text := nullif(p_datos ->> 'para_semana', ''); paid text := nullif(p_datos ->> 'para_assign_id', '');
  nin text := nullif(p_datos ->> 'nuevo_in', ''); nout text := coalesce(p_datos ->> 'nuevo_out', '');
  nid bigint;
begin
  select staff_id into sid from public.accesos where dni = d;
  if sid is null then perform pg_sleep(0.4); return json_build_object('ok', false, 'error', 'dni'); end if;
  if t not in ('ceder','cambio','horario') then return json_build_object('ok', false, 'error', 'datos'); end if;
  if sem !~ '^\d{4}-\d{2}-\d{2}$' or not public.turno_de(sem, aid, sid) then return json_build_object('ok', false, 'error', 'turno'); end if;
  if t in ('ceder','cambio') and (para is null or para = sid) then return json_build_object('ok', false, 'error', 'datos'); end if;
  if t = 'cambio' and (psem is null or psem !~ '^\d{4}-\d{2}-\d{2}$' or not public.turno_de(psem, paid, para)) then
    return json_build_object('ok', false, 'error', 'turno'); end if;
  if t = 'horario' and (nin is null or nin !~ '^\d{2}:\d{2}$' or (nout <> '' and nout !~ '^\d{2}:\d{2}$')) then
    return json_build_object('ok', false, 'error', 'datos'); end if;
  if exists (select 1 from public.solicitudes where staff_id = sid and assign_id = aid and estado = 'pendiente') then
    return json_build_object('ok', false, 'error', 'repetida'); end if;
  if (select count(*) from public.solicitudes where staff_id = sid and created_at > now() - interval '1 day') >= 10 then
    return json_build_object('ok', false, 'error', 'muchas'); end if;
  insert into public.solicitudes (staff_id, tipo, semana, assign_id, para_staff, para_semana, para_assign_id, nuevo_in, nuevo_out, motivo, resumen)
  values (sid, t, sem, aid, case when t = 'horario' then null else para end, case when t = 'cambio' then psem end, case when t = 'cambio' then paid end,
          case when t = 'horario' then nin end, case when t = 'horario' then nout end,
          left(coalesce(p_datos ->> 'motivo', ''), 500), left(coalesce(p_datos ->> 'resumen', ''), 600))
  returning id into nid;
  return json_build_object('ok', true, 'id', nid, 'staff_id', sid);
end $$;

-- La persona ve sus pedidos (y se identifica) con su DNI.
create or replace function public.mis_solicitudes(p_dni text)
returns json language plpgsql security definer set search_path = public as $$
declare d text := regexp_replace(coalesce(p_dni,''), '\D', '', 'g'); sid text;
begin
  select staff_id into sid from public.accesos where dni = d;
  if sid is null then perform pg_sleep(0.4); return json_build_object('ok', false, 'error', 'dni'); end if;
  return json_build_object('ok', true, 'staff_id', sid, 'solicitudes',
    (select coalesce(json_agg(row_to_json(x) order by x.created_at desc), '[]'::json) from
      (select id, tipo, semana, assign_id, resumen, motivo, estado, respuesta, created_at, resuelto_at
       from public.solicitudes where staff_id = sid order by created_at desc limit 15) x));
end $$;

-- La persona cancela un pedido que todavía no se resolvió.
create or replace function public.cancelar_solicitud(p_dni text, p_id bigint)
returns json language plpgsql security definer set search_path = public as $$
declare d text := regexp_replace(coalesce(p_dni,''), '\D', '', 'g'); sid text;
begin
  select staff_id into sid from public.accesos where dni = d;
  if sid is null then return json_build_object('ok', false, 'error', 'dni'); end if;
  update public.solicitudes set estado = 'cancelada', resuelto_at = now(), resuelto_por = 'la misma persona'
  where id = p_id and staff_id = sid and estado = 'pendiente';
  return json_build_object('ok', found);
end $$;

revoke all on function public.solicitar_cambio(text, jsonb) from public;
revoke all on function public.mis_solicitudes(text) from public;
revoke all on function public.cancelar_solicitud(text, bigint) from public;
grant execute on function public.solicitar_cambio(text, jsonb) to anon, authenticated;
grant execute on function public.mis_solicitudes(text) to anon, authenticated;
grant execute on function public.cancelar_solicitud(text, bigint) to anon, authenticated;

do $$ begin
  alter publication supabase_realtime add table public.solicitudes;
exception when duplicate_object then null; end $$;
