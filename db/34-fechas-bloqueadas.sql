-- ============================================================
-- PETHOUSE · Fechas bloqueadas manualmente por el anfitrión
-- ------------------------------------------------------------
-- El anfitrión puede "congelar" fechas de un hospedaje propio sin que exista una reserva
-- real — para viajes, mantenimiento, o cualquier motivo por el que no quiera recibir
-- huéspedes esos días, sin tener que pausar el hospedaje entero (eso lo esconde de Buscar
-- por completo; esto solo bloquea fechas puntuales, el hospedaje sigue visible).
--
-- Mismo patrón de `reservas` (ver 11-reservas-pendientes-mascotas.sql): `hasta` es
-- EXCLUSIVA (el día de salida no cuenta como ocupado) y un EXCLUDE por GiST evita que dos
-- bloqueos del mismo hospedaje se traslapen. La validación cruzada contra `reservas` (no
-- dejar bloquear fechas ya reservadas, y no dejar reservar fechas ya bloqueadas) se hace en
-- la aplicación (ver pethouse-api/src/routes/hospedajes.js y routes/reservas.js) — un
-- EXCLUDE no puede cruzar dos tablas distintas.
--
-- GET /api/hospedajes/:id/disponibilidad (pública, la usa el huésped antes de reservar)
-- ahora incluye estos rangos junto con los de `reservas` — ver el UNION en esa consulta.
--
-- Aplicar después de 33-respuesta-resena.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 34-fechas-bloqueadas.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS hospedaje_fechas_bloqueadas (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hospedaje_id UUID NOT NULL REFERENCES hospedajes(id) ON DELETE CASCADE,
    desde        DATE NOT NULL,
    hasta        DATE NOT NULL,
    motivo       TEXT,
    creado_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CHECK (hasta > desde),
    EXCLUDE USING gist (hospedaje_id WITH =, daterange(desde, hasta) WITH &&)
);

CREATE INDEX IF NOT EXISTS idx_fechas_bloqueadas_hospedaje ON hospedaje_fechas_bloqueadas (hospedaje_id);
