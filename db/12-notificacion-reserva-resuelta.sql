-- ============================================================
-- PETHOUSE · Aviso de solicitud de reserva resuelta (aceptada/rechazada)
-- ------------------------------------------------------------
-- Mismo patrón que 10-notificacion-verificacion.sql: sin push notifications (ADR-7), el
-- huésped se entera de que el anfitrión aceptó o rechazó su solicitud la próxima vez que
-- abre la app. `notificado` marca si ya lo vio. El anfitrión la pone en FALSE al aceptar o
-- rechazar (ver POST /api/reservas/:id/aceptar|rechazar en routes/reservas.js); el huésped
-- la pone en TRUE apenas la app le muestra el aviso (POST /api/reservas/:id/notificado).
--
-- Default TRUE (no FALSE): así las reservas que ya estaban confirmadas/rechazadas ANTES de
-- esta migración no disparan un aviso retroactivo la primera vez que alguien abre la app
-- después de aplicarla — solo las resoluciones nuevas, a partir de ahora, empiezan en FALSE.
--
-- Aplicar después de 11-reservas-pendientes-mascotas.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 12-notificacion-reserva-resuelta.sql
-- ============================================================

ALTER TABLE reservas ADD COLUMN IF NOT EXISTS notificado BOOLEAN NOT NULL DEFAULT TRUE;
