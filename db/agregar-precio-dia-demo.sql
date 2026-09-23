-- ============================================================
-- PETHOUSE · Precio de día de ejemplo en algunos hospedajes del seed
-- ------------------------------------------------------------
-- Para poder probar la reserva de un solo día (ver db/35-reserva-mismo-dia.sql) sin tener
-- que editar un hospedaje a mano primero: le pone `precio_dia` a 6 hospedajes de ejemplo,
-- uno de cada tipo, todos en Bogotá — el resto de hospedajes del seed quedan igual (sin
-- precio de día, o sea sin esa opción), para poder seguir probando también ese caso.
--
-- No es una migración de esquema (no crea columnas ni tablas) — solo datos de ejemplo.
-- Se puede correr las veces que haga falta sin duplicar nada (son UPDATE por id).
--
-- Aplicar:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f agregar-precio-dia-demo.sql
-- ============================================================

-- Guardería Patitas Felices — Chapinero (guardería, $48.000/noche)
UPDATE hospedajes SET precio_dia = 30000 WHERE id = '20000000-0000-0000-0000-000000000001';

-- VetStay Clínica Veterinaria — Chapinero (veterinaria, $85.000/noche)
UPDATE hospedajes SET precio_dia = 55000 WHERE id = '20000000-0000-0000-0000-000000000004';

-- Apartamento Pet Friendly — Galerías (apartamento, $62.000/noche)
UPDATE hospedajes SET precio_dia = 40000 WHERE id = '20000000-0000-0000-0000-000000000010';

-- Cuidadora a domicilio — Chapinero (a domicilio, $70.000/noche)
UPDATE hospedajes SET precio_dia = 45000 WHERE id = '20000000-0000-0000-0000-000000000013';

-- Guardería Suba Bonita (guardería, $46.000/noche)
UPDATE hospedajes SET precio_dia = 30000 WHERE id = '20000000-0000-0000-0000-000000000019';

-- Finca Páramo de Sumapaz (casa campestre, $95.000/noche)
UPDATE hospedajes SET precio_dia = 60000 WHERE id = '20000000-0000-0000-0000-000000000035';
