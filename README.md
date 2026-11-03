# Turnos Osvaldo

Planificación de turnos del personal para Barrio Norte y Producción. Es una página estática (GitHub Pages) que guarda los datos en Supabase.

- Cualquiera con el link ve el calendario, el horario del equipo y "Mi horario" (`…/#mi-<id>`).
- Para planificar, cargar ausencias, ver horas, costos e historial hay que ingresar con un usuario editor.

## Puesta en marcha

1. **Supabase → SQL Editor:** pegar y ejecutar `supabase/schema.sql`.
2. **Supabase → Authentication → Users → Add user:** crear el usuario de cada editor (email y contraseña, marcando *Auto Confirm User*).
3. **Supabase → SQL Editor:** dar permiso de edición a cada uno:
   ```sql
   insert into public.editores (email) values ('tu-email@ejemplo.com');
   ```
4. **Supabase → Authentication → Sign In / Providers:** desactivar *Allow new users to sign up* (los usuarios se crean a mano).
5. **`config.js`:** completar la Project URL y la clave anon/publishable (Project Settings → API).
6. **GitHub → Settings → Pages:** *Deploy from a branch*, rama `main`, carpeta `/ (root)`.

## Archivos

- `index.html`: toda la app.
- `config.js`: datos públicos del proyecto de Supabase.
- `supabase/schema.sql`: tablas y permisos.
