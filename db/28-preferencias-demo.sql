-- Preferencias de anfitrión para los 3 anfitriones de Bogotá del seed (02-seed.sql): sin
-- esto, el nuevo filtro real de especie (Perros/Gatos) en Buscar (ver
-- pethouse-api/src/routes/hospedajes.js, especie=perro|gato) no encontraba NINGÚN resultado
-- en los datos de ejemplo — `preferencias_anfitrion` existe desde 06-verificacion-
-- anfitrion.sql, pero nunca se llenaba en el seed. Cada anfitrión declara aquí lo mismo que
-- ya sugieren sus descripciones ("Apto para gatos", "Cuidado de gatos y perros", clínica que
-- atiende ambas especies): acepta perros y gatos.
INSERT INTO preferencias_anfitrion (usuario_id, especies, modalidades, tamanos) VALUES
('00000000-0000-0000-0000-000000000002', ARRAY['perro','gato'], ARRAY['dias','horas'], ARRAY['pequeno','mediano','grande']),
('00000000-0000-0000-0000-000000000005', ARRAY['perro','gato'], ARRAY['dias'],         ARRAY['pequeno','mediano','grande']),
('00000000-0000-0000-0000-000000000007', ARRAY['perro','gato'], ARRAY['dias','horas'], ARRAY['pequeno','mediano','grande'])
ON CONFLICT (usuario_id) DO NOTHING;
