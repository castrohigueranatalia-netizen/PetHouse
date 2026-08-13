-- ============================================================
-- PETHOUSE · Reservas completadas/vencidas automáticamente
-- ------------------------------------------------------------
-- Antes nada marcaba una reserva 'confirmada' como 'completada' cuando pasaba la fecha de
-- salida — sin eso, ni "Dejar reseña" (huésped) ni "Calificar huésped" (anfitrión, ver
-- db/15-resenas-huesped.sql) se podían usar NUNCA en la práctica.
--
-- Sin job en segundo plano (cero infra extra, mismo criterio del resto del MVP — sin
-- Redis, sin cron): `completarReservasVencidas()` (pethouse-api/src/lib/completarReservas.js)
-- hace dos UPDATE:
--   1) 'confirmada' con `hasta` ya pasada  → 'completada' (la estadía ocurrió).
--   2) 'pendiente' con `hasta` ya pasada   → 'rechazada' (el anfitrión nunca respondió antes
--      de que llegara la fecha; se trata como vencida/expirada, y libera esas fechas —ver
--      el EXCLUDE de 11-reservas-pendientes-mascotas.sql, que solo protege pendiente/
--      confirmada— y notifica al huésped por el mismo camino que aceptar/rechazar).
-- Se llama al leer reservas (GET /reservas/mias, /reservas/:id, /hospedajes/:id/reservas,
-- POST /reservas/:id/cancelar) — así el estado siempre está al día apenas alguien lo toca.
--
-- Estos índices parciales aceleran esas dos consultas (solo indexan las filas en el estado
-- que cada una necesita revisar).
--
-- Aplicar después de 15-resenas-huesped.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 16-completar-reservas-vencidas.sql
-- ============================================================

CREATE INDEX IF NOT EXISTS idx_reservas_confirmada_hasta ON reservas (hasta) WHERE estado = 'confirmada';
CREATE INDEX IF NOT EXISTS idx_reservas_pendiente_hasta ON reservas (hasta) WHERE estado = 'pendiente';
