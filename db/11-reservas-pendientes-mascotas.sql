-- ============================================================
-- PETHOUSE · Solicitudes de reserva: pendiente/rechazada + mascotas concretas
-- ------------------------------------------------------------
-- Antes toda reserva nacía ya "confirmada" automáticamente. Ahora nace en estado
-- 'pendiente' y el anfitrión debe aceptarla o rechazarla (ver POST /api/reservas/:id/aceptar
-- y /rechazar en reservas.js) antes de que cuente como confirmada.
--
-- También se guarda QUÉ mascotas concretas van en cada reserva — antes 'mascotas' en la
-- tabla reservas era solo un número, sin vínculo a las mascotas reales del usuario, así que
-- el anfitrión no tenía forma de ver su raza ni sus notas/requerimientos antes de decidir.
--
-- El EXCLUDE que evita traslapes de fechas por hospedaje ahora solo mira reservas
-- 'pendiente'/'confirmada' — antes aplicaba a TODAS las filas sin importar el estado, así
-- que una reserva cancelada o rechazada dejaba esas fechas bloqueadas para siempre.
--
-- Aplicar después de 10-notificacion-verificacion.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 11-reservas-pendientes-mascotas.sql
-- ============================================================

ALTER TYPE estado_reserva ADD VALUE IF NOT EXISTS 'pendiente';
ALTER TYPE estado_reserva ADD VALUE IF NOT EXISTS 'rechazada';

ALTER TABLE reservas ALTER COLUMN estado SET DEFAULT 'pendiente';

ALTER TABLE reservas DROP CONSTRAINT IF EXISTS chk_no_traslape;
ALTER TABLE reservas ADD CONSTRAINT chk_no_traslape
    EXCLUDE USING gist (hospedaje_id WITH =, daterange(desde, hasta) WITH &&)
    WHERE (estado IN ('pendiente', 'confirmada'));

CREATE TABLE IF NOT EXISTS reserva_mascotas (
    reserva_id UUID NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
    mascota_id UUID NOT NULL REFERENCES mascotas(id) ON DELETE RESTRICT,
    PRIMARY KEY (reserva_id, mascota_id)
);
CREATE INDEX IF NOT EXISTS idx_reserva_mascotas_mascota ON reserva_mascotas (mascota_id);
