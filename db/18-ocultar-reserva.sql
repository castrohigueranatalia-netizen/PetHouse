-- ============================================================
-- PETHOUSE · Ocultar una reserva ya resuelta del panel de "Mis reservas"
-- ------------------------------------------------------------
-- El huésped puede quitar de su lista las reservas que ya no están activas
-- ('completada', 'cancelada', 'rechazada') — no borra la fila de verdad: una reserva tiene
-- pago (`pagos`, ON DELETE RESTRICT) y puede tener reseñas asociadas, así que un DELETE real
-- fallaría o destruiría historial de verdad. `oculta_por_usuario` solo la saca del listado
-- de ESE usuario (ver GET /api/reservas/mias en routes/reservas.js) — el anfitrión, el admin
-- y cualquier reporte siguen viéndola igual que antes.
--
-- Default FALSE: todas las reservas existentes siguen visibles tal cual hasta que alguien
-- las oculte a propósito.
--
-- Aplicar después de 17-notificacion-solicitud-anfitrion.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 18-ocultar-reserva.sql
-- ============================================================

ALTER TABLE reservas ADD COLUMN IF NOT EXISTS oculta_por_usuario BOOLEAN NOT NULL DEFAULT FALSE;
