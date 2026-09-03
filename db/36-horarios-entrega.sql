-- ============================================================
-- PETHOUSE · Hora de entrega y de recogida de la mascota
-- ------------------------------------------------------------
-- El huésped ahora declara A QUÉ HORA lleva a su mascota y a qué hora la recoge — antes solo
-- se pedían las fechas (día/noche), sin ninguna hora, así que el anfitrión no tenía forma de
-- saber si debía esperar al huésped a las 7am o a las 7pm. Se pide siempre, tanto para
-- reservas "por noches" (hora_entrega es la del día que llega, hora_recogida la del día que
-- se va) como "mismo día" (las dos caen el mismo día — ver db/35-reserva-mismo-dia.sql).
--
-- `TIME` (no `TIMESTAMPTZ`): es una hora del reloj sin fecha ni huso horario asociado —
-- Bogotá no cambia de huso horario en el año, así que no hace falta más que eso. Columnas
-- NULLABLE (no NOT NULL): las reservas ya existentes antes de este cambio no tienen esta
-- información y no hay un valor razonable que inventarles; POST /api/reservas exige ambas
-- para reservas NUEVAS desde ahora (ver reservas.js), pero a nivel de esquema quedan
-- opcionales para no romper filas viejas.
--
-- Aplicar después de 35-reserva-mismo-dia.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 36-horarios-entrega.sql
-- ============================================================

ALTER TABLE reservas ADD COLUMN IF NOT EXISTS hora_entrega TIME;
ALTER TABLE reservas ADD COLUMN IF NOT EXISTS hora_recogida TIME;
