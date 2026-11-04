-- Turnos Osvaldo: niveles de acceso.
--   Personal (sin usuario): calendario, mi horario, cambios de turno y fichar.
--   Encargado (con usuario): además planifica la semana y arma el horario del equipo.
--   Administrador (con usuario): todo, incluidos costos, personas, aprobaciones y accesos.
-- Correr después de schema.sql, fichadas.sql y cambios.sql. Se puede correr más de una vez.

alter table public.editores add column if not exists rol text not null default 'admin';
alter table public.editores alter column rol set default 'encargado';
do $$ begin
  alter table public.editores add constraint editores_rol check (rol in ('admin','encargado'));
exception when duplicate_object then null; end $$;

-- es_editor() = administrador (lo usan fichadas, accesos y pedidos de cambio).
create or replace function public.es_editor() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.editores where email = lower(auth.jwt() ->> 'email') and rol = 'admin');
$$;
-- es_encargado() = encargado o administrador.
create or replace function public.es_encargado() returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.editores where email = lower(auth.jwt() ->> 'email'));
$$;

-- Documentos: el administrador todo; el encargado lee el historial y guarda semanas, semanas tipo e historial.
drop policy if exists "editores leen todo" on public.docs;
drop policy if exists "editores crean" on public.docs;
drop policy if exists "editores modifican" on public.docs;
drop policy if exists "editores borran" on public.docs;
drop policy if exists "admin lee todo" on public.docs;
drop policy if exists "admin crea" on public.docs;
drop policy if exists "admin modifica" on public.docs;
drop policy if exists "admin borra" on public.docs;
drop policy if exists "encargados leen historial" on public.docs;
drop policy if exists "encargados crean" on public.docs;
drop policy if exists "encargados modifican" on public.docs;
create policy "admin lee todo" on public.docs for select to authenticated using (public.es_editor());
create policy "admin crea" on public.docs for insert to authenticated with check (public.es_editor());
create policy "admin modifica" on public.docs for update to authenticated using (public.es_editor()) with check (public.es_editor());
create policy "admin borra" on public.docs for delete to authenticated using (public.es_editor());
create policy "encargados leen historial" on public.docs for select to authenticated
  using (public.es_encargado() and path like 'historial/%');
create policy "encargados crean" on public.docs for insert to authenticated
  with check (public.es_encargado() and (path like 'weeks/%' or path like 'plantillas/%' or path like 'historial/%'));
create policy "encargados modifican" on public.docs for update to authenticated
  using (public.es_encargado() and (path like 'weeks/%' or path like 'plantillas/%' or path like 'historial/%'))
  with check (public.es_encargado() and (path like 'weeks/%' or path like 'plantillas/%' or path like 'historial/%'));

-- Accesos: el administrador ve, agrega y quita mails (no se puede quitar a sí mismo).
grant select, insert, update, delete on public.editores to authenticated;
drop policy if exists "admin ve accesos" on public.editores;
drop policy if exists "admin agrega accesos" on public.editores;
drop policy if exists "admin cambia accesos" on public.editores;
drop policy if exists "admin quita accesos" on public.editores;
create policy "admin ve accesos" on public.editores for select to authenticated using (public.es_editor());
create policy "admin agrega accesos" on public.editores for insert to authenticated
  with check (public.es_editor() and email = lower(email));
create policy "admin cambia accesos" on public.editores for update to authenticated
  using (public.es_editor() and email <> lower(auth.jwt() ->> 'email')) with check (public.es_editor() and email = lower(email));
create policy "admin quita accesos" on public.editores for delete to authenticated
  using (public.es_editor() and email <> lower(auth.jwt() ->> 'email'));
