-- ============================================================
-- PETHOUSE · Reservas de un solo día (entrega y recogida el mismo día)
-- ------------------------------------------------------------
-- Antes toda reserva exigía al menos 1 noche (`hasta > desde`, ver chk_fechas en
-- 01-esquema.sql). Ahora un hospedaje puede además ofrecer un precio de DÍA aparte del
-- precio por noche (`hospedajes.precio_dia`, opcional — si el anfitrión no lo define, ese
-- hospedaje simplemente no ofrece la opción de un solo día) para cuando el huésped deja a
-- su mascota en la mañana y la recoge esa misma noche, sin quedarse a dormir.
--
-- Se sigue guardando `hasta = desde + 1` internamente (NO se toca chk_fechas ni el EXCLUDE
-- de traslapes: siguen funcionando igual, el día completo queda ocupado) — lo que cambia es
-- que `reservas.mismo_dia` marca esa reserva como "de un solo día" y `reservas.precio_dia`
-- guarda una copia del precio de día vigente AL MOMENTO de reservar (mismo criterio que
-- `precio_noche`, que tampoco seria un precio "vivo" — si el anfitrión lo cambia después, no
-- debe alterar reservas ya hechas). `total` se recalcula para usar `precio_dia` en vez de
-- `precio_noche * noches` cuando la reserva es de un solo día — hay que recrear la columna
-- (DROP + ADD) porque Postgres no permite editar la expresión de una columna GENERATED ya
-- existente.
--
-- Aplicar después de 34-fechas-bloqueadas.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 35-reserva-mismo-dia.sql
-- ============================================================

ALTER TABLE hospedajes ADD COLUMN IF NOT EXISTS precio_dia NUMERIC(10,2)
    CHECK (precio_dia IS NULL OR precio_dia > 0);

ALTER TABLE reservas ADD COLUMN IF NOT EXISTS mismo_dia BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE reservas ADD COLUMN IF NOT EXISTS precio_dia NUMERIC(10,2);

ALTER TABLE reservas DROP COLUMN IF EXISTS total;
ALTER TABLE reservas ADD COLUMN total NUMERIC(10,2) GENERATED ALWAYS AS (
    CASE WHEN mismo_dia THEN COALESCE(precio_dia, precio_noche) ELSE precio_noche * (hasta - desde) END
    + limpieza + servicio
) STORED;
