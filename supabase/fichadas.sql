-- Turnos Osvaldo: fichero de entrada y salida con DNI + PIN.
-- Pegar completo en Supabase → SQL Editor → New query → Run. Se puede correr más de una vez.

create extension if not exists pgcrypto with schema extensions;

-- DNI y PIN de cada persona. El PIN se guarda cifrado; nadie lo puede leer, ni los editores.
create table if not exists public.accesos (
  staff_id text primary key,
  dni text not null unique,
  pin_hash text not null,
  fallos int not null default 0,
  bloqueado_hasta timestamptz,
  updated_at timestamptz not null default now()
);

-- Cada marca de entrada o salida. La hora la pone el servidor.
create table if not exists public.fichadas (
  id bigint generated always as identity primary key,
  staff_id text not null,
  tipo text not null check (tipo in ('in','out')),
  at timestamptz not null default now(),
  origen text not null default 'persona' check (origen in ('persona','manual')),
  por text
);
create index if not exists fichadas_staff_at on public.fichadas (staff_id, at desc);
create index if not exists fichadas_at on public.fichadas (at);

alter table public.accesos enable row level security;
alter table public.fichadas enable row level security;

revoke all on public.accesos from anon, authenticated;
revoke all on public.fichadas from anon, authenticated;
-- Los editores ven qué DNI tiene cada uno (no el PIN) y pueden quitar un acceso.
grant select (staff_id, dni, fallos, bloqueado_hasta, updated_at) on public.accesos to authenticated;
grant delete on public.accesos to authenticated;
grant select, insert, delete on public.fichadas to authenticated;
grant usage on sequence public.fichadas_id_seq to authenticated;

drop policy if exists "editores ven accesos" on public.accesos;
create policy "editores ven accesos" on public.accesos for select to authenticated using (public.es_editor());
drop policy if exists "editores quitan accesos" on public.accesos;
create policy "editores quitan accesos" on public.accesos for delete to authenticated using (public.es_editor());
drop policy if exists "editores ven fichadas" on public.fichadas;
create policy "editores ven fichadas" on public.fichadas for select to authenticated using (public.es_editor());
drop policy if exists "editores cargan fichadas" on public.fichadas;
create policy "editores cargan fichadas" on public.fichadas for insert to authenticated with check (public.es_editor() and origen = 'manual');
drop policy if exists "editores borran fichadas" on public.fichadas;
create policy "editores borran fichadas" on public.fichadas for delete to authenticated using (public.es_editor());

-- Un editor carga o cambia el DNI y el PIN de una persona. PIN vacío = deja el que tenía.
create or replace function public.set_acceso(p_staff text, p_dni text, p_pin text)
returns void language plpgsql security definer set search_path = public, extensions as $$
declare d text := regexp_replace(coalesce(p_dni,''), '\D', '', 'g');
begin
  if not public.es_editor() then raise exception 'Solo un editor puede cargar accesos'; end if;
  if length(d) < 6 or length(d) > 9 then raise exception 'El DNI tiene que tener entre 6 y 9 números'; end if;
  if coalesce(p_pin,'') <> '' and p_pin !~ '^\d{4,6}$' then raise exception 'El PIN tiene que tener de 4 a 6 números'; end if;
  if exists (select 1 from public.accesos where dni = d and staff_id <> p_staff) then raise exception 'Ese DNI ya lo tiene otra persona'; end if;
  if exists (select 1 from public.accesos where staff_id = p_staff) then
    update public.accesos set dni = d, fallos = 0, bloqueado_hasta = null, updated_at = now(),
      pin_hash = case when coalesce(p_pin,'') <> '' then crypt(p_pin, gen_salt('bf')) else pin_hash end
    where staff_id = p_staff;
  else
    if coalesce(p_pin,'') = '' then raise exception 'Falta el PIN'; end if;
    insert into public.accesos (staff_id, dni, pin_hash) values (p_staff, d, crypt(p_pin, gen_salt('bf')));
  end if;
end $$;

-- La persona ficha con DNI + PIN. p_tipo: 'in', 'out' o 'ver' (solo consulta).
create or replace function public.fichar(p_dni text, p_pin text, p_tipo text)
returns json language plpgsql security definer set search_path = public, extensions as $$
declare
  d text := regexp_replace(coalesce(p_dni,''), '\D', '', 'g');
  u public.accesos;
  ult public.fichadas;
  nueva timestamptz;
  dup boolean := false;
begin
  select * into u from public.accesos where dni = d for update;
  if not found then
    perform pg_sleep(0.5);
    return json_build_object('ok', false, 'error', 'datos');
  end if;
  if u.bloqueado_hasta is not null and u.bloqueado_hasta > now() then
    return json_build_object('ok', false, 'error', 'bloqueado', 'hasta', u.bloqueado_hasta);
  end if;
  if u.pin_hash <> crypt(coalesce(p_pin,''), u.pin_hash) then
    update public.accesos set
      fallos = case when fallos + 1 >= 5 then 0 else fallos + 1 end,
      bloqueado_hasta = case when fallos + 1 >= 5 then now() + interval '15 minutes' else null end
    where staff_id = u.staff_id;
    return json_build_object('ok', false, 'error', case when u.fallos + 1 >= 5 then 'bloqueado' else 'datos' end);
  end if;
  update public.accesos set fallos = 0, bloqueado_hasta = null where staff_id = u.staff_id;
  select * into ult from public.fichadas where staff_id = u.staff_id order by at desc limit 1;
  if p_tipo in ('in','out') then
    -- Un doble toque en menos de 2 minutos no crea otra marca.
    if ult.id is not null and ult.tipo = p_tipo and ult.at > now() - interval '2 minutes' then
      dup := true; nueva := ult.at;
    else
      insert into public.fichadas (staff_id, tipo) values (u.staff_id, p_tipo) returning at into nueva;
    end if;
  elsif p_tipo <> 'ver' then
    return json_build_object('ok', false, 'error', 'tipo');
  end if;
  return json_build_object('ok', true, 'staff_id', u.staff_id, 'tipo', p_tipo, 'at', nueva, 'repetida', dup,
    'recientes', (select coalesce(json_agg(json_build_object('tipo', f.tipo, 'at', f.at) order by f.at desc), '[]'::json)
                  from (select tipo, at from public.fichadas where staff_id = u.staff_id order by at desc limit 8) f));
end $$;

revoke all on function public.set_acceso(text, text, text) from public, anon;
grant execute on function public.set_acceso(text, text, text) to authenticated;
revoke all on function public.fichar(text, text, text) from public;
grant execute on function public.fichar(text, text, text) to anon, authenticated;

-- Las fichadas aparecen en vivo en la pestaña Fichadas.
do $$ begin
  alter publication supabase_realtime add table public.fichadas;
exception when duplicate_object then null; end $$;
