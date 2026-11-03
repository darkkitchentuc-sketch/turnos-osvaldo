-- Turnos Osvaldo: tablas y permisos.
-- Pegar completo en Supabase → SQL Editor → New query → Run.

-- Todos los datos de la app: cada fila es un documento (por ejemplo "weeks/2026-11-02") con su contenido en JSON.
create table if not exists public.docs (
  path text primary key,
  data jsonb not null,
  updated_at timestamptz not null default now()
);

-- Emails de las personas que pueden editar (planificar, cargar ausencias, ver costos e historial).
create table if not exists public.editores (
  email text primary key
);

alter table public.docs enable row level security;
alter table public.editores enable row level security;

create or replace function public.es_editor() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.editores where email = lower(auth.jwt() ->> 'email'));
$$;

-- Cualquiera con el link ve los horarios, pero no los costos ni el historial.
drop policy if exists "lectura publica" on public.docs;
create policy "lectura publica" on public.docs for select to anon, authenticated
  using (path not like 'privado/%' and path not like 'historial/%');

-- Los editores leen y escriben todo.
drop policy if exists "editores leen todo" on public.docs;
create policy "editores leen todo" on public.docs for select to authenticated using (public.es_editor());
drop policy if exists "editores crean" on public.docs;
create policy "editores crean" on public.docs for insert to authenticated with check (public.es_editor());
drop policy if exists "editores modifican" on public.docs;
create policy "editores modifican" on public.docs for update to authenticated using (public.es_editor()) with check (public.es_editor());
drop policy if exists "editores borran" on public.docs;
create policy "editores borran" on public.docs for delete to authenticated using (public.es_editor());

-- Cada usuario puede comprobar si él mismo es editor.
drop policy if exists "ver mi permiso" on public.editores;
create policy "ver mi permiso" on public.editores for select to authenticated
  using (email = lower(auth.jwt() ->> 'email'));

-- Cambios en vivo entre pantallas abiertas.
do $$ begin
  alter publication supabase_realtime add table public.docs;
exception when duplicate_object then null; end $$;
