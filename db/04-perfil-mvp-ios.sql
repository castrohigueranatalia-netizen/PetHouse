-- ============================================================
-- PETHOUSE · Migración adicional para el MVP de iOS
-- ------------------------------------------------------------
-- Agrega la columna que necesita `PATCH /api/auth/me` (editar perfil) para guardar la foto
-- subida vía `POST /api/subidas`. Las tablas `mascotas` y `favoritos` ya existían en
-- 01-esquema.sql con exactamente los campos que necesitan las nuevas rutas de mascotas y
-- favoritos — no requieren migración.
--
-- Aplicar después de 01-esquema.sql (o en cualquier momento sobre una base ya en uso,
-- es idempotente vía IF NOT EXISTS):
--   psql -h localhost -U pethouse -d pethouse -f 04-perfil-mvp-ios.sql
-- ============================================================

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS foto_url TEXT;
