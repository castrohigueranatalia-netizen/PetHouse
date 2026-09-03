-- ============================================================
-- PETHOUSE · Índice para hospedajes.localidad
-- ------------------------------------------------------------
-- Se agregó la columna `localidad` en 08-localidades-bogota.sql sin su índice — quedó al
-- mismo nivel que `ciudad`/`tipo` (ver idx_hospedajes_ciudad/idx_hospedajes_tipo en
-- 01-esquema.sql), que sí lo tienen. GET /api/hospedajes?localidad= y el GROUP BY de
-- GET /api/hospedajes/localidades lo usan en cada búsqueda — con pocos hospedajes hoy no se
-- nota, pero es la misma clase de índice que ya existe para los otros filtros.
--
-- Aplicar después de 08-localidades-bogota.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 09-index-localidad.sql
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_hospedajes_localidad ON hospedajes (localidad);
