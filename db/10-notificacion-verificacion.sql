-- ============================================================
-- PETHOUSE · Aviso de solicitud de anfitrión resuelta
-- ------------------------------------------------------------
-- Sin push notifications (ver ADR-7, fase 2), el usuario se entera de que su solicitud fue
-- aprobada/rechazada la próxima vez que abre la app: `notificado` marca si ya vio el
-- resultado. El admin la pone en FALSE al aprobar/rechazar (ver routes/admin.js); el
-- cliente la pone en TRUE apenas muestra el aviso (POST /api/anfitrion/verificacion/notificado).
--
-- Default TRUE (no FALSE): así las solicitudes que ya estaban aprobadas/rechazadas ANTES
-- de esta migración no disparan un aviso retroactivo la primera vez que alguien abre la
-- app después de aplicarla — solo las resoluciones nuevas, a partir de ahora, empiezan en
-- FALSE (ver el UPDATE explícito en admin.js).
--
-- Aplicar después de 09-index-localidad.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 10-notificacion-verificacion.sql
-- ============================================================

ALTER TABLE verificaciones_anfitrion ADD COLUMN IF NOT EXISTS notificado BOOLEAN NOT NULL DEFAULT TRUE;
