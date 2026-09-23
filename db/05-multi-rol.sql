-- ============================================================
-- PETHOUSE · Un usuario puede ser cliente Y anfitrión a la vez
-- ------------------------------------------------------------
-- Antes, `usuarios.rol` era exclusivo (cliente | anfitrion | admin), forzando a elegir un
-- solo tipo de cuenta para siempre y obligando a crear una cuenta aparte para poder
-- ofrecer hospedaje además de reservar. Ahora "ser anfitrión" es una capacidad que
-- cualquier cuenta puede activar en cualquier momento (registro o después, desde el
-- perfil) — como "Conviértete en anfitrión" en Airbnb, no un tipo de cuenta distinto.
--
-- `rol` se conserva (sigue siendo 'cliente' | 'anfitrion' | 'admin') solo para saber la
-- intención principal con la que alguien se registró y para el caso especial 'admin'; la
-- autorización real de acciones de anfitrión (publicar hospedaje, ver reservas recibidas)
-- ahora se basa en `es_anfitrion`, no en `rol` — ver middleware `soloAnfitrion`.
--
-- Aplicar después de 01-esquema.sql (idempotente vía IF NOT EXISTS):
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 05-multi-rol.sql
-- ============================================================

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS es_anfitrion BOOLEAN NOT NULL DEFAULT FALSE;

-- Los usuarios que ya se registraron como 'anfitrion' (incluido el seed) conservan la
-- capacidad — no se les revoca nada con esta migración.
UPDATE usuarios SET es_anfitrion = TRUE WHERE rol IN ('anfitrion', 'admin') AND NOT es_anfitrion;
