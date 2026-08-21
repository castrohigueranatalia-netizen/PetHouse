-- Comisión de PetHouse: por ahora es SOLO informativa — no hay pasarela de pagos conectada
-- todavía (la tabla `pagos` ya existía para eso, ver 01-esquema.sql, comentario "fase 2:
-- pasarela"), así que nadie cobra nada de verdad todavía. Esto deja lista la base para
-- cuando sí se conecte: cada pago guarda el % de comisión que aplicaba EN ESE MOMENTO (no
-- uno global que, si se cambia después, alteraría retroactivamente reportes ya generados).
--
-- Se guarda en `pagos`, no en `reservas`: conceptualmente la comisión es un asunto del
-- pago/split de dinero, no de la reserva en sí — mismo criterio que ya separaba esas dos
-- tablas desde el principio.
ALTER TABLE entidad_legal ADD COLUMN IF NOT EXISTS comision_porcentaje NUMERIC(5,2) NOT NULL DEFAULT 10.00;

ALTER TABLE pagos ADD COLUMN IF NOT EXISTS comision_porcentaje NUMERIC(5,2) NOT NULL DEFAULT 10.00;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS comision_monto NUMERIC(10,2)
  GENERATED ALWAYS AS (round(monto * comision_porcentaje / 100, 2)) STORED;
ALTER TABLE pagos ADD COLUMN IF NOT EXISTS monto_anfitrion NUMERIC(10,2)
  GENERATED ALWAYS AS (monto - round(monto * comision_porcentaje / 100, 2)) STORED;
