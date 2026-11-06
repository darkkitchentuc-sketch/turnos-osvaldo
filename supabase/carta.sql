-- Turnos Osvaldo: link de edición para que la caja actualice la carta online sin usuario.
-- Pegar completo en Supabase → SQL Editor → New query → Run. Se puede correr más de una vez.
-- Después, el administrador crea el link desde la carta (link + #editar → ingresar con email → "Link de edición para la caja").
-- La clave del link (#editar=12345678) se guarda cifrada acá, como un PIN.

create extension if not exists pgcrypto with schema extensions;

-- Una sola fila con el PIN cifrado. Nadie la puede leer directamente.
create table if not exists public.carta_pin (
  id int primary key default 1 check (id = 1),
  pin_hash text,
  fallos int not null default 0,
  bloqueado_hasta timestamptz,
  updated_at timestamptz not null default now()
);
alter table public.carta_pin enable row level security;
revoke all on public.carta_pin from anon, authenticated;

-- Revisa el PIN. Con 5 errores seguidos se bloquea 15 minutos.
create or replace function public.carta_pin_valido(p_pin text)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare c public.carta_pin;
begin
  select * into c from public.carta_pin where id = 1 for update;
  if not found or c.pin_hash is null then return 'sinpin'; end if;
  if c.bloqueado_hasta is not null and c.bloqueado_hasta > now() then return 'bloqueado'; end if;
  if c.pin_hash <> crypt(coalesce(p_pin,''), c.pin_hash) then
    update public.carta_pin set
      fallos = case when fallos + 1 >= 5 then 0 else fallos + 1 end,
      bloqueado_hasta = case when fallos + 1 >= 5 then now() + interval '15 minutes' else null end
    where id = 1;
    perform pg_sleep(0.5);
    return case when c.fallos + 1 >= 5 then 'bloqueado' else 'mal' end;
  end if;
  update public.carta_pin set fallos = 0, bloqueado_hasta = null where id = 1;
  return 'ok';
end $$;

-- Para la pantalla de ingreso: dice si el PIN es correcto.
create or replace function public.carta_entrar(p_pin text)
returns text language plpgsql security definer set search_path = public, extensions as $$
begin
  return public.carta_pin_valido(p_pin);
end $$;

-- Guarda la carta (precios y "No disponible"). Vale con el PIN o con un usuario administrador.
create or replace function public.carta_guardar(p_pin text, p_data jsonb)
returns text language plpgsql security definer set search_path = public, extensions as $$
declare r text;
begin
  if not public.es_editor() then
    r := public.carta_pin_valido(p_pin);
    if r <> 'ok' then return r; end if;
  end if;
  if jsonb_typeof(p_data) <> 'object' or octet_length(p_data::text) > 100000 then return 'datos'; end if;
  insert into public.docs (path, data, updated_at) values ('carta/osvaldo', p_data, now())
  on conflict (path) do update set data = excluded.data, updated_at = now();
  return 'ok';
end $$;

-- Solo el administrador cambia el PIN (4 a 8 números).
create or replace function public.carta_cambiar_pin(p_pin text)
returns text language plpgsql security definer set search_path = public, extensions as $$
begin
  if not public.es_editor() then raise exception 'Solo un administrador puede cambiar el PIN de la carta'; end if;
  if coalesce(p_pin,'') !~ '^\d{4,8}$' then return 'formato'; end if;
  insert into public.carta_pin (id, pin_hash, fallos, bloqueado_hasta, updated_at)
  values (1, crypt(p_pin, gen_salt('bf')), 0, null, now())
  on conflict (id) do update set pin_hash = excluded.pin_hash, fallos = 0, bloqueado_hasta = null, updated_at = now();
  return 'ok';
end $$;

revoke all on function public.carta_pin_valido(text) from public, anon, authenticated;
grant execute on function public.carta_entrar(text) to anon, authenticated;
grant execute on function public.carta_guardar(text, jsonb) to anon, authenticated;
grant execute on function public.carta_cambiar_pin(text) to authenticated;
