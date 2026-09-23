-- ============================================================
-- PETHOUSE · Fotos de la mascota
-- ------------------------------------------------------------
-- Se agregan a la ficha que el anfitrión ve al recibir una solicitud de reserva
-- (13-ficha-mascota.sql) — mismo patrón que `hospedajes.fotos`: arreglo de URLs que
-- devuelve POST /api/subidas (ya existente, ver routes/subidas.js), no los bytes de la
-- imagen.
--
-- Aplicar después de 13-ficha-mascota.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 14-fotos-mascota.sql
-- ============================================================

ALTER TABLE mascotas ADD COLUMN IF NOT EXISTS fotos TEXT[] NOT NULL DEFAULT '{}';
