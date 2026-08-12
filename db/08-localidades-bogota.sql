-- ============================================================
-- PETHOUSE · La app se enfoca solo en Bogotá, segmentada por localidad
-- ------------------------------------------------------------
-- Decisión de producto: en vez de una búsqueda "cualquier ciudad de Colombia" con muy
-- pocos hospedajes por ciudad, la app opera solo en Bogotá y organiza la búsqueda y el
-- mapa por las 20 localidades oficiales del Distrito. `hospedajes.ciudad` se deja intacto
-- (los hospedajes fuera de Bogotá del seed original quedan en la base, pero la API deja de
-- devolverlos — ver pethouse-api/src/routes/hospedajes.js) y se agrega `localidad`, que es
-- obligatoria para hospedajes nuevos en Bogotá.
--
-- Aplicar después de 07-admin-seed.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 08-localidades-bogota.sql
-- ============================================================

ALTER TABLE hospedajes ADD COLUMN IF NOT EXISTS localidad TEXT
  CHECK (localidad IN (
    'Usaquén', 'Chapinero', 'Santa Fe', 'San Cristóbal', 'Usme', 'Tunjuelito', 'Bosa',
    'Kennedy', 'Fontibón', 'Engativá', 'Suba', 'Barrios Unidos', 'Teusaquillo',
    'Los Mártires', 'Antonio Nariño', 'Puente Aranda', 'La Candelaria',
    'Rafael Uribe Uribe', 'Ciudad Bolívar', 'Sumapaz'
  ));

-- Ubica los 6 hospedajes de Bogotá que ya traía el seed (02-seed.sql) en su localidad real
-- (el `barrio` que tenían es un barrio DENTRO de la localidad, no la localidad misma —
-- ej. "Galerías" es un barrio de la localidad Teusaquillo).
UPDATE hospedajes SET localidad = 'Chapinero'   WHERE id = '20000000-0000-0000-0000-000000000001'; -- Chapinero Alto
UPDATE hospedajes SET localidad = 'Chapinero'   WHERE id = '20000000-0000-0000-0000-000000000004'; -- Chapinero
UPDATE hospedajes SET localidad = 'Teusaquillo' WHERE id = '20000000-0000-0000-0000-000000000010'; -- Galerías
UPDATE hospedajes SET localidad = 'Chapinero'   WHERE id = '20000000-0000-0000-0000-000000000013'; -- Chapinero Alto
UPDATE hospedajes SET localidad = 'Usaquén'     WHERE id = '20000000-0000-0000-0000-000000000016'; -- Usaquén
UPDATE hospedajes SET localidad = 'Teusaquillo' WHERE id = '20000000-0000-0000-0000-000000000018'; -- Teusaquillo

-- Hospedajes nuevos en otras localidades de Bogotá, para que la búsqueda/mapa por
-- localidad tenga sentido desde el primer arranque (antes solo había 3 localidades con
-- datos: Chapinero, Teusaquillo, Usaquén).
INSERT INTO hospedajes (id, anfitrion_id, tipo, titulo, descripcion, ciudad, barrio, localidad, ubicacion, cobertura_radio_m, precio_noche, convivencia, max_mascotas, rating, num_resenas, destacado, servicios, reglas, fotos, activo) VALUES
('20000000-0000-0000-0000-000000000019', '00000000-0000-0000-0000-000000000003', 'guarderia', 'Guardería Suba Bonita', 'Guardería con zonas verdes cerca a los humedales de Suba, ideal para perros activos. Grupos pequeños organizados por tamaño y energía, con paseos por senderos naturales.', 'Bogotá', 'Suba Rincón', 'Suba', ST_SetSRID(ST_MakePoint(-74.093, 4.741), 4326), NULL, 46000, 'compartida', 8, 4.7, 92, false, '{Cerca a los humedales,Grupos por tamaño,Paseos por senderos,Cámaras en vivo,Alimentación incluida,Espacio cubierto y al aire libre}', '{Vacunas al día,Desparasitación reciente,Mascotas sociables}', '{/semilla/g1.jpg,/semilla/g2.jpg}', TRUE),
('20000000-0000-0000-0000-000000000020', '00000000-0000-0000-0000-000000000004', 'apartamento', 'Apartamento Pet Friendly — Kennedy', 'Apartamento familiar en Kennedy con patio compartido y anfitriona presente todo el día. Máximo 2 huéspedes para garantizar atención personalizada.', 'Bogotá', 'Kennedy Central', 'Kennedy', ST_SetSRID(ST_MakePoint(-74.153, 4.628), 4326), NULL, 50000, 'individual', 2, 4.6, 64, false, '{Anfitriona en casa,Patio compartido,Paseos 2 veces al día,Cámaras en sala,Alimentación a la carta}', '{Vacunas al día,Mascotas menores de 20 kg,Reportar alergias}', '{/semilla/a1.jpg,/semilla/a2.jpg}', TRUE),
('20000000-0000-0000-0000-000000000021', '00000000-0000-0000-0000-000000000002', 'domicilio', 'Cuidado a domicilio — Engativá', 'Cuidado en tu propia casa en Engativá, con visitas dos veces al día o estancia completa. Reporte diario con fotos y comunicación constante con el dueño.', 'Bogotá', 'Engativá Centro', 'Engativá', ST_SetSRID(ST_MakePoint(-74.117, 4.705), 4326), 12000, 58000, 'individual', 2, 4.8, 37, false, '{La cuidadora va a tu casa,Paseos diarios,Reporte con fotos,Rutina exacta,Seguro de responsabilidad}', '{Mascotas con vacunas al día,Zona Engativá y alrededores,Entrevista previa gratuita}', '{/semilla/a1.jpg,/semilla/a2.jpg}', TRUE),
('20000000-0000-0000-0000-000000000022', '00000000-0000-0000-0000-000000000005', 'veterinaria', 'VetStay Fontibón', 'Hospedaje clínico en Fontibón con supervisión médica permanente, ideal para mascotas mayores o en tratamiento. Chequeo diario incluido.', 'Bogotá', 'Fontibón Centro', 'Fontibón', ST_SetSRID(ST_MakePoint(-74.145, 4.676), 4326), NULL, 80000, 'individual', 4, 4.9, 71, true, '{Supervisión médica 24/7,Administración de medicamentos,Chequeo diario,Hospitalización cómoda,Urgencias incluidas}', '{Historia clínica al ingreso,Vacunas al día,Mascotas con condición médica bienvenidas}', '{/semilla/v1.jpg,/semilla/v2.jpg}', TRUE),
('20000000-0000-0000-0000-000000000023', '00000000-0000-0000-0000-000000000007', 'domicilio', 'Pet sitter en tu casa — Bosa', 'Cuidado en tu hogar en Bosa mientras viajas: tu mascota mantiene su rutina, sus paseos y su cama. Reporte diario incluido.', 'Bogotá', 'Bosa Centro', 'Bosa', ST_SetSRID(ST_MakePoint(-74.180, 4.619), 4326), 12000, 55000, 'individual', 3, 4.7, 28, false, '{Estancia completa en tu hogar,Paseos 2 veces al día,Fotos y videos diarios,Rutina personalizada,Comunicación constante}', '{Vacunas al día,Mascotas de hasta 25 kg,Coordinación previa de rutinas}', '{/semilla/a2.jpg,/semilla/a1.jpg}', TRUE),
('20000000-0000-0000-0000-000000000024', '00000000-0000-0000-0000-000000000006', 'apartamento', 'Loft Pet Friendly — La Candelaria', 'Loft en el centro histórico de La Candelaria, a pasos de los principales puntos turísticos. Máximo 2 huéspedes, paseos por el Chorro de Quevedo y alrededores.', 'Bogotá', 'La Candelaria', 'La Candelaria', ST_SetSRID(ST_MakePoint(-74.075, 4.596), 4326), NULL, 58000, 'individual', 2, 4.5, 21, false, '{Anfitrión en casa,Zona histórica,Paseos por el centro,Cámaras en sala,Apto para gatos}', '{Vacunas al día,Mascotas menores de 15 kg,Reportar alergias o medicamentos}', '{/semilla/a1.jpg,/semilla/a2.jpg}', TRUE),
('20000000-0000-0000-0000-000000000025', '00000000-0000-0000-0000-000000000003', 'guarderia', 'Guardería Puente Aranda', 'Guardería industrial-chic en Puente Aranda con estancias individuales y grupales según preferencia. Personal certificado en primeros auxilios caninos.', 'Bogotá', 'Puente Aranda Centro', 'Puente Aranda', ST_SetSRID(ST_MakePoint(-74.114, 4.615), 4326), NULL, 44000, 'compartida', 6, 4.6, 45, false, '{Juego supervisado,Paseos diarios,Alimentación incluida,Reporte fotográfico diario,Espacio interior climatizado}', '{Vacunas al día obligatorias,Mascotas mayores de 4 meses,Desparasitación reciente}', '{/semilla/g1.jpg,/semilla/g2.jpg}', TRUE),
('20000000-0000-0000-0000-000000000026', '00000000-0000-0000-0000-000000000004', 'domicilio', 'Cuidado a domicilio — Barrios Unidos', 'Cuidado en tu casa en Barrios Unidos con visitas programadas o estancia parcial. Perfecto para gatos y perros que prefieren no salir de su territorio.', 'Bogotá', '12 de Octubre', 'Barrios Unidos', ST_SetSRID(ST_MakePoint(-74.083, 4.667), 4326), 12000, 56000, 'individual', 2, 4.7, 19, false, '{Visitas 2 veces al día,Paseos mañana y tarde,Reporte por WhatsApp,Limpieza de areneros (gatos),Flexibilidad de horarios}', '{Vacunas al día,Zona Barrios Unidos y aledaños,Indicar dieta y medicamentos}', '{/semilla/a1.jpg,/semilla/a2.jpg}', TRUE),
('20000000-0000-0000-0000-000000000027', '00000000-0000-0000-0000-000000000007', 'domicilio', 'Cuidadora a domicilio — Rafael Uribe Uribe', 'Cuidado a domicilio en Rafael Uribe Uribe con visitas dos veces al día. Experiencia con mascotas senior y administración de medicamentos.', 'Bogotá', 'Marco Fidel Suárez', 'Rafael Uribe Uribe', ST_SetSRID(ST_MakePoint(-74.112, 4.558), 4326), 12000, 52000, 'individual', 2, 4.6, 15, false, '{Visitas mañana y tarde,Reporte fotográfico diario,Alimentación y medicamentos,Experiencia con mascotas senior,Llaves con seguro}', '{Vacunas al día,Zona Rafael Uribe Uribe y alrededores,Entrevista previa gratuita}', '{/semilla/a2.jpg,/semilla/a1.jpg}', TRUE);
