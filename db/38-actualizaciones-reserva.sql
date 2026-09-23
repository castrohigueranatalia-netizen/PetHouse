-- ============================================================
-- PETHOUSE · Actualizaciones durante la estadía
-- ------------------------------------------------------------
-- El anfitrión puede publicar notas y/o fotos de cómo va la mascota MIENTRAS la reserva está
-- confirmada (el huésped ya la dejó, todavía no la recoge) — antes no había ninguna forma de
-- que el huésped supiera algo de su mascota entre que la dejaba y la recogía, algo que en
-- este tipo de apps genera mucha confianza.
--
-- `notas`/`fotos` ambos opcionales POR SEPARADO (una actualización puede ser solo una foto,
-- o solo un texto), pero el CHECK exige que venga AL MENOS uno de los dos — una fila
-- completamente vacía no aporta nada. `fotos` es `TEXT[]`, mismo patrón que
-- `hospedajes.fotos`/`mascotas.fotos`: URLs ya subidas por separado vía POST /api/subidas,
-- esta tabla no guarda bytes.
--
-- Aplicar después de 37-horarios-hospedaje.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 38-actualizaciones-reserva.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS actualizaciones_reserva (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reserva_id  UUID NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
    autor_id    UUID NOT NULL REFERENCES usuarios(id),
    notas       TEXT,
    fotos       TEXT[] NOT NULL DEFAULT '{}',
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_actualizacion_tiene_contenido
        CHECK (notas IS NOT NULL OR array_length(fotos, 1) > 0)
);

CREATE INDEX IF NOT EXISTS idx_actualizaciones_reserva ON actualizaciones_reserva (reserva_id, creado_en);
