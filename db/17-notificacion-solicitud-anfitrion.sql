-- ============================================================
-- PETHOUSE · Aviso de solicitud de reserva NUEVA (para el anfitrión)
-- ------------------------------------------------------------
-- Mismo patrón que 12-notificacion-reserva-resuelta.sql, pero en la otra dirección: acá el
-- huésped crea la solicitud y el ANFITRIÓN todavía no la vio. `notificado_anfitrion` marca
-- si ya la vio. Se pone en FALSE al crear la reserva (ver POST /api/reservas en
-- routes/reservas.js); el anfitrión la pone en TRUE apenas la app le muestra el aviso
-- (POST /api/reservas/:id/notificado-anfitrion).
--
-- Default TRUE (no FALSE): así las solicitudes que ya estaban pendientes ANTES de esta
-- migración no disparan un aviso retroactivo la primera vez que el anfitrión abre la app
-- después de aplicarla — solo las solicitudes nuevas, a partir de ahora, empiezan en FALSE.
--
-- Aplicar después de 16-completar-reservas-vencidas.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 17-notificacion-solicitud-anfitrion.sql
-- ============================================================

ALTER TABLE reservas ADD COLUMN IF NOT EXISTS notificado_anfitrion BOOLEAN NOT NULL DEFAULT TRUE;
