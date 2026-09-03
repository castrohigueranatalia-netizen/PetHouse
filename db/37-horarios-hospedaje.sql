-- ============================================================
-- PETHOUSE · Rango de horas de entrega y de recogida por hospedaje
-- ------------------------------------------------------------
-- El anfitrión ahora define, por hospedaje, EN QUÉ RANGO acepta que le lleven/recojan una
-- mascota (ej. entrega de 7am a 9am, recogida de 6pm a 7pm) — antes el huésped podía elegir
-- CUALQUIER hora del día (ver db/36-horarios-entrega.sql), sin que el anfitrión tuviera
-- forma de limitarlo a cuando de verdad puede recibir gente.
--
-- NULLABLE los cuatro: un hospedaje sin rango configurado no queda bloqueado — el cliente
-- (NuevaReservaViewModel) usa un rango por defecto razonable (6am–9pm) en su lugar, para no
-- obligar a todos los anfitriones existentes a editar su hospedaje antes de poder recibir
-- reservas nuevas.
--
-- Aplicar después de 36-horarios-entrega.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 37-horarios-hospedaje.sql
-- ============================================================

ALTER TABLE hospedajes ADD COLUMN IF NOT EXISTS horario_entrega_desde TIME;
ALTER TABLE hospedajes ADD COLUMN IF NOT EXISTS horario_entrega_hasta TIME;
ALTER TABLE hospedajes ADD COLUMN IF NOT EXISTS horario_recogida_desde TIME;
ALTER TABLE hospedajes ADD COLUMN IF NOT EXISTS horario_recogida_hasta TIME;
