-- ============================================================
-- PETHOUSE · Denuncias también para reseñas falsas o abusivas
-- ------------------------------------------------------------
-- Amplía `denuncias` (ver 30-denuncias.sql) para poder reportar una reseña, no solo un
-- anfitrión/usuario/mensaje. Cubre las dos tablas de reseñas que ya existían:
--   - `resenas`         → el huésped califica un hospedaje (ver 01-esquema.sql)
--   - `resenas_usuario` → el anfitrión califica al huésped (ver 15-resenas-huesped.sql)
-- `usuario_denunciado_id` sigue siendo obligatorio: para una reseña es quien la escribió
-- (`autor_id`), igual que en los otros tipos siempre es la persona, nunca el contenido.
-- `resena_titulo`/`resena_texto`/`resena_rating` guardan una copia de la reseña AL MOMENTO
-- de denunciar (mismo criterio que `mensaje_texto` para mensajes de chat): si la reseña se
-- borra o cambia después, el admin igual puede ver qué se denunció.
--
-- Aplicar después de 30-denuncias.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 31-denuncias-resenas.sql
-- ============================================================

ALTER TABLE denuncias DROP CONSTRAINT IF EXISTS denuncias_tipo_check;
ALTER TABLE denuncias ADD CONSTRAINT chk_denuncias_tipo
  CHECK (tipo IN ('anfitrion', 'usuario', 'mensaje', 'resena'));

ALTER TABLE denuncias ADD COLUMN IF NOT EXISTS resena_titulo TEXT;
ALTER TABLE denuncias ADD COLUMN IF NOT EXISTS resena_texto TEXT;
ALTER TABLE denuncias ADD COLUMN IF NOT EXISTS resena_rating SMALLINT;
