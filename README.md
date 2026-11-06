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

## Fichero (entrada y salida)
1. En Supabase → SQL Editor, pegá y corré `supabase/fichadas.sql` y después `supabase/cambios.sql`.
2. En **Personas y puestos**, a cada persona cargale su DNI.
3. La pantalla para fichar es el link de la app con `#fichar` al final. Las marcas se ven en la pestaña **Fichadas** y completan las horas reales.

## Cambios de turno
Cada persona pide el cambio en **Cambios de turno** con su DNI. Llega un mail al email de avisos (se configura en **Aprobación de cambios**; la primera vez FormSubmit manda un mail para activarlo). Al aprobar, el calendario se actualiza solo.

## Niveles de acceso
Correr `supabase/niveles.sql`. Personal (sin usuario): Calendario, Mi horario, Cambios de turno, Fichadas. Encargado: además Planificar semana y Horario del equipo. Administrador: todo. Los accesos se dan en **Ajustes → Accesos** y el usuario se crea en Supabase → Authentication → Users.

## Carta online
- Link para mandar a los clientes: `https://darkkitchentuc-sketch.github.io/turnos-osvaldo/carta/`
- Para actualizar precios y "No disponible": el mismo link con `#editar` al final, ingresando con un usuario **administrador**. Se guarda en Supabase (`docs`, path `carta/osvaldo`); no hace falta correr SQL.
- Los platos y sus textos están en `carta/index.html` (lista `CARTA`). Cada plato tiene un id fijo donde se guardan su precio y disponibilidad.
