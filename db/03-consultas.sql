-- ============================================================
-- PETHOUSE · Consultas de ejemplo (PostgreSQL + PostGIS)
-- ------------------------------------------------------------
-- Incluye búsquedas espaciales, disponibilidad y negocio.
-- Ejecuta primero: 01-esquema.sql y 02-seed.sql
-- ============================================================

-- ============================================================
-- 1. BÚSQUEDAS ESPACIALES (PostGIS)
-- ============================================================

-- 1.1 Hospedajes a menos de 5 km de un punto (Bogotá, Chapinero)
--     Usa el índice GIST automáticamente (ST_DWithin con geography).
SELECT titulo, ciudad, barrio, precio_noche,
       ROUND(ST_Distance(ubicacion, ST_SetSRID(ST_MakePoint(-74.072, 4.711), 4326)::geography)) AS distancia_m
  FROM hospedajes
 WHERE ST_DWithin(ubicacion, ST_SetSRID(ST_MakePoint(-74.072, 4.711), 4326)::geography, 5000)
 ORDER BY distancia_m;

-- 1.2 Función lista: hospedajes cerca de una coordenada
SELECT * FROM hospedajes_cerca(6.244, -75.581, 8000);  -- Medellín, radio 8 km

-- 1.3 Cuidadores a domicilio que CUBREN una dirección dada
--     (el cuidador cubre si el punto del cliente está dentro de su radio)
SELECT h.titulo, h.ciudad, h.barrio, h.precio_noche,
       ROUND(ST_Distance(h.ubicacion, ST_SetSRID(ST_MakePoint(-74.067, 4.695), 4326)::geography)) AS distancia_m
  FROM hospedajes h
 WHERE h.tipo = 'domicilio'
   AND h.cobertura_radio_m IS NOT NULL
   AND ST_DWithin(h.ubicacion, ST_SetSRID(ST_MakePoint(-74.067, 4.695), 4326)::geography, h.cobertura_radio_m)
 ORDER BY distancia_m;

-- 1.4 Distancia entre dos ciudades (para "¿a qué distancia queda el hospedaje?")
SELECT ST_Distance(
         (SELECT ubicacion FROM hospedajes WHERE id = '20000000-0000-0000-0000-000000000001'),
         (SELECT ubicacion FROM hospedajes WHERE id = '20000000-0000-0000-0000-000000000007')
       ) AS distancia_bogota_chia_m;

-- ============================================================
-- 2. DISPONIBILIDAD Y RESERVAS
-- ============================================================

-- 2.1 Hospedajes disponibles para un rango de fechas (función)
SELECT titulo, ciudad, precio_noche, rating
  FROM hospedajes_disponibles('2026-09-10', '2026-09-14');

-- 2.2 ¿Un hospedaje concreto está libre en esas fechas?
SELECT NOT EXISTS (
    SELECT 1 FROM reservas
     WHERE hospedaje_id = '20000000-0000-0000-0000-000000000001'
       AND estado = 'confirmada'
       AND desde < '2026-09-14' AND hasta > '2026-09-10'
) AS disponible;

-- 2.3 Crear una reserva (transacción con bloqueo anti-doble-reserva)
--     Nota: la restricción EXCLUDE (chk_no_traslape) rechaza automáticamente
--     cualquier reserva que se solape con otra confirmada del mismo hospedaje.
BEGIN;
INSERT INTO reservas (usuario_id, hospedaje_id, desde, hasta, mascotas, precio_noche, limpieza, servicio)
VALUES ('00000000-0000-0000-0000-000000000001',
        '20000000-0000-0000-0000-000000000001',
        '2026-12-01', '2026-12-05', 1, 48000, 28800, 19200)
RETURNING codigo, total;
COMMIT;

-- 2.4 Ocupación futura de un hospedaje (calendario de disponibilidad)
SELECT desde, hasta, estado
  FROM reservas
 WHERE hospedaje_id = '20000000-0000-0000-0000-000000000001'
   AND hasta >= CURRENT_DATE
 ORDER BY desde;

-- ============================================================
-- 3. BÚSQUEDA COMBINADA (la del buscador de la app)
-- ============================================================

-- 3.1 Todo en una: texto + tipo + convivencia + fechas + radio
SELECT * FROM buscar_hospedajes(
    lat => 4.711, lng => -74.072, radio_m => 20000,
    f_desde => '2026-09-10', f_hasta => '2026-09-14',
    p_tipo => 'guarderia', q => 'guardería'
);

-- 3.2 Búsqueda de texto simple (índice GIN + pg_trgm)
SELECT titulo, ciudad FROM hospedajes
 WHERE to_tsvector('spanish', titulo || ' ' || descripcion || ' ' || ciudad)
       @@ plainto_tsquery('spanish', 'campestre piscina');

-- 3.3 Autocompletado por ciudad con trigramas
SELECT DISTINCT ciudad FROM hospedajes WHERE ciudad ILIKE '%medel%';

-- ============================================================
-- 4. NEGOCIO Y REPORTES
-- ============================================================

-- 4.1 Ingresos por mes (reservas confirmadas)
SELECT date_trunc('month', creado_en) AS mes,
       COUNT(*) AS reservas,
       SUM(total) AS ingresos
  FROM reservas
 WHERE estado = 'confirmada'
 GROUP BY 1 ORDER BY 1 DESC;

-- 4.2 Mejores hospedajes por ciudad
SELECT ciudad, titulo, rating, num_resenas
  FROM hospedajes
 ORDER BY rating DESC, num_resenas DESC
 LIMIT 10;

-- 4.3 Actividades más populares
SELECT a.nombre, COUNT(pa.id) AS veces_reservada
  FROM actividades a
  LEFT JOIN plan_actividades pa ON pa.actividad_id = a.id
 GROUP BY a.id, a.nombre
 ORDER BY veces_reservada DESC;

-- 4.4 No leídos por anfitrión (badge del chat)
SELECT COUNT(*) AS no_leidos
  FROM mensajes m
  JOIN conversaciones c ON c.id = m.conversacion_id
 WHERE c.anfitrion_id = '00000000-0000-0000-0000-000000000002'
   AND m.remitente_id <> '00000000-0000-0000-0000-000000000002'
   AND m.leido = FALSE;

-- 4.5 Últimas reseñas de un hospedaje (con autor)
SELECT r.rating, r.titulo, r.texto, u.nombre AS autor, r.creado_en
  FROM resenas r
  JOIN usuarios u ON u.id = r.autor_id
 WHERE r.hospedaje_id = '20000000-0000-0000-0000-000000000001'
 ORDER BY r.creado_en DESC;

-- ============================================================
-- 5. MANTENIMIENTO
-- ============================================================

-- 5.1 Tablas más grandes (diagnóstico)
SELECT relname AS tabla, n_live_tup AS filas_aprox
  FROM pg_stat_user_tables ORDER BY n_live_tup DESC;

-- 5.2 Vacuum de análisis (tras grandes cargas)
-- VACUUM ANALYZE;

-- 5.3 Verificar que PostGIS está activo
SELECT postgis_version();
