-- ============================================================
-- PETHOUSE · Esquema PostgreSQL + PostGIS
-- ------------------------------------------------------------
-- Base de datos de la plataforma de hospedaje de mascotas.
-- Requiere: PostgreSQL 14+ con extensión PostGIS 3+
--
-- Para levantar una base local lista:
--   docker compose up -d        (ver docker-compose.yml)
--   psql -h localhost -U pethouse -d pethouse -f 01-esquema.sql
-- ============================================================

-- ------------------------------------------------------------
-- 0. EXTENSIONES
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS postgis;          -- datos espaciales (geography)
CREATE EXTENSION IF NOT EXISTS citext;           -- emails case-insensitive
CREATE EXTENSION IF NOT EXISTS pg_trgm;          -- búsqueda parcial de texto
CREATE EXTENSION IF NOT EXISTS btree_gist;       -- (opcional) para exclusión de fechas

-- ------------------------------------------------------------
-- 1. TIPOS ENUM
-- ------------------------------------------------------------
CREATE TYPE rol_usuario      AS ENUM ('cliente', 'anfitrion', 'admin');
CREATE TYPE tipo_hospedaje   AS ENUM ('guarderia', 'veterinaria', 'campestre', 'apartamento', 'domicilio');
CREATE TYPE tipo_convivencia AS ENUM ('cualquiera', 'compartida', 'individual');
CREATE TYPE estado_reserva   AS ENUM ('confirmada', 'cancelada', 'completada');
CREATE TYPE estado_pago      AS ENUM ('pendiente', 'aprobado', 'rechazado', 'reembolsado');
CREATE TYPE tipo_actividad   AS ENUM ('paseos', 'piscina', 'entrenamiento', 'spa', 'fotos', 'social');

-- ------------------------------------------------------------
-- 2. TABLAS NÚCLEO
-- ------------------------------------------------------------

-- Usuarios: dueños, anfitriones y administradores
CREATE TABLE usuarios (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre        TEXT NOT NULL,
    email         CITEXT NOT NULL UNIQUE,
    telefono      TEXT,
    password_hash TEXT NOT NULL,                 -- bcrypt/argon2 (nunca en claro)
    rol           rol_usuario NOT NULL DEFAULT 'cliente',
    verificado    BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Mascotas de los clientes
CREATE TABLE mascotas (
    id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    nombre     TEXT NOT NULL,
    especie    TEXT NOT NULL DEFAULT 'perro',   -- perro / gato / otro
    raza       TEXT,
    peso_kg    NUMERIC(5,2),
    vacunas_dia BOOLEAN NOT NULL DEFAULT FALSE,
    notas      TEXT,
    creado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_mascotas_usuario ON mascotas (usuario_id);

-- Hospedajes: guarderías, veterinarias, casas campestres,
-- apartamentos y cuidadores a domicilio (tipo = 'domicilio')
CREATE TABLE hospedajes (
    id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    anfitrion_id     UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    tipo             tipo_hospedaje NOT NULL,
    titulo           TEXT NOT NULL,
    descripcion      TEXT NOT NULL,
    ciudad           TEXT NOT NULL,
    barrio           TEXT,
    direccion        TEXT,
    -- ⭐ PostGIS: punto geográfico (lat, lng en grados decimales)
    ubicacion        GEOGRAPHY(POINT, 4326) NOT NULL,
    -- Para 'domicilio': radio de cobertura del cuidador (metros)
    cobertura_radio_m INTEGER CHECK (cobertura_radio_m IS NULL OR cobertura_radio_m > 0),
    precio_noche     NUMERIC(10,2) NOT NULL CHECK (precio_noche > 0),
    convivencia      tipo_convivencia NOT NULL DEFAULT 'cualquiera',
    max_mascotas     SMALLINT NOT NULL DEFAULT 1 CHECK (max_mascotas BETWEEN 1 AND 50),
    rating           NUMERIC(3,2) NOT NULL DEFAULT 0 CHECK (rating BETWEEN 0 AND 5),
    num_resenas      INTEGER NOT NULL DEFAULT 0,
    destacado        BOOLEAN NOT NULL DEFAULT FALSE,
    servicios        TEXT[] NOT NULL DEFAULT '{}',
    reglas           TEXT[] NOT NULL DEFAULT '{}',
    fotos            TEXT[] NOT NULL DEFAULT '{}',
    activo           BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en        TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ⭐ Índices espaciales y de búsqueda
CREATE INDEX idx_hospedajes_geom  ON hospedajes USING GIST (ubicacion);
CREATE INDEX idx_hospedajes_ciudad ON hospedajes (ciudad);
CREATE INDEX idx_hospedajes_tipo  ON hospedajes (tipo);
CREATE INDEX idx_hospedajes_anfitrion ON hospedajes (anfitrion_id);
CREATE INDEX idx_hospedajes_tsv ON hospedajes
    USING GIN (to_tsvector('spanish', titulo || ' ' || descripcion || ' ' || ciudad || ' ' || coalesce(barrio,'')));

-- Reservas (con rangos de fechas para control de disponibilidad)
CREATE TABLE reservas (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    codigo        TEXT NOT NULL UNIQUE DEFAULT ('PH-' || upper(substr(md5(random()::text), 1, 8))),
    usuario_id    UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    hospedaje_id  UUID NOT NULL REFERENCES hospedajes(id) ON DELETE RESTRICT,
    desde         DATE NOT NULL,
    hasta         DATE NOT NULL,
    noches        SMALLINT GENERATED ALWAYS AS (hasta - desde) STORED,
    mascotas      SMALLINT NOT NULL DEFAULT 1 CHECK (mascotas >= 1),
    precio_noche  NUMERIC(10,2) NOT NULL,
    limpieza      NUMERIC(10,2) NOT NULL DEFAULT 0,
    servicio      NUMERIC(10,2) NOT NULL DEFAULT 0,
    total         NUMERIC(10,2) GENERATED ALWAYS AS (precio_noche * (hasta - desde) + limpieza + servicio) STORED,
    estado        estado_reserva NOT NULL DEFAULT 'confirmada',
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_fechas CHECK (hasta > desde),
    CONSTRAINT chk_mascotas CHECK (mascotas <= 50)
);
CREATE INDEX idx_reservas_usuario  ON reservas (usuario_id);
CREATE INDEX idx_reservas_hospedaje ON reservas (hospedaje_id);
CREATE INDEX idx_reservas_fechas   ON reservas (desde, hasta);

-- ⭐ (Avanzado) Evita dobles reservas solapadas por hospedaje
-- Requiere la extensión btree_gist (ya incluida arriba).
-- En producción conviene además bloquear la fila del hospedaje
-- (SELECT ... FOR UPDATE) dentro de la transacción de reserva.
ALTER TABLE reservas ADD CONSTRAINT chk_no_traslape
    EXCLUDE USING gist (hospedaje_id WITH =, daterange(desde, hasta) WITH &&);

-- Actividades caninas (globales o específicas de un hospedaje)
CREATE TABLE actividades (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    hospedaje_id UUID REFERENCES hospedajes(id) ON DELETE CASCADE, -- NULL = disponible en todos
    nombre      TEXT NOT NULL,
    tipo        tipo_actividad NOT NULL,
    descripcion TEXT,
    duracion    TEXT,
    precio      NUMERIC(10,2) NOT NULL CHECK (precio >= 0),
    activa      BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_actividades_tipo ON actividades (tipo);

-- Actividades agregadas a una reserva (plan de la mascota)
CREATE TABLE plan_actividades (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reserva_id   UUID NOT NULL REFERENCES reservas(id) ON DELETE CASCADE,
    actividad_id UUID NOT NULL REFERENCES actividades(id) ON DELETE RESTRICT,
    fecha        DATE,
    precio       NUMERIC(10,2) NOT NULL,
    creado_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
    UNIQUE (reserva_id, actividad_id, fecha)
);
CREATE INDEX idx_plan_reserva ON plan_actividades (reserva_id);

-- Reseñas (una por reserva)
CREATE TABLE resenas (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reserva_id   UUID NOT NULL UNIQUE REFERENCES reservas(id) ON DELETE CASCADE,
    autor_id     UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,
    hospedaje_id UUID NOT NULL REFERENCES hospedajes(id) ON DELETE CASCADE,
    rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    titulo       TEXT,
    texto        TEXT,
    creado_en    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_resenas_hospedaje ON resenas (hospedaje_id);

-- ⭐ Trigger: mantiene rating y num_resenas del hospedaje
CREATE OR REPLACE FUNCTION actualizar_rating_hospedaje() RETURNS TRIGGER AS $$
BEGIN
    UPDATE hospedajes h
       SET rating      = COALESCE((SELECT ROUND(AVG(rating)::numeric, 2) FROM resenas WHERE hospedaje_id = COALESCE(NEW.hospedaje_id, OLD.hospedaje_id)), 0),
           num_resenas = COALESCE((SELECT COUNT(*) FROM resenas WHERE hospedaje_id = COALESCE(NEW.hospedaje_id, OLD.hospedaje_id)), 0)
     WHERE h.id = COALESCE(NEW.hospedaje_id, OLD.hospedaje_id);
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_rating_resena
    AFTER INSERT OR UPDATE OR DELETE ON resenas
    FOR EACH ROW EXECUTE FUNCTION actualizar_rating_hospedaje();

-- Favoritos del usuario
CREATE TABLE favoritos (
    usuario_id   UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    hospedaje_id UUID NOT NULL REFERENCES hospedajes(id) ON DELETE CASCADE,
    creado_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (usuario_id, hospedaje_id)
);

-- Chat interno: conversaciones dueño ⇄ anfitrión
CREATE TABLE conversaciones (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id   UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    anfitrion_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    hospedaje_id UUID REFERENCES hospedajes(id) ON DELETE SET NULL,
    creado_en    TIMESTAMPTZ NOT NULL DEFAULT now(),
    CONSTRAINT chk_distintos CHECK (usuario_id <> anfitrion_id)
);
CREATE INDEX idx_conv_usuario ON conversaciones (usuario_id);
CREATE INDEX idx_conv_anfitrion ON conversaciones (anfitrion_id);

CREATE TABLE mensajes (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    conversacion_id UUID NOT NULL REFERENCES conversaciones(id) ON DELETE CASCADE,
    remitente_id    UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    texto           TEXT NOT NULL,
    leido           BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_msgs_conversacion ON mensajes (conversacion_id, creado_en);

-- Pagos (integración futura con pasarela)
CREATE TABLE pagos (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reserva_id  UUID NOT NULL UNIQUE REFERENCES reservas(id) ON DELETE RESTRICT,
    monto       NUMERIC(10,2) NOT NULL CHECK (monto >= 0),
    metodo      TEXT,                              -- 'pse', 'tarjeta', 'nequi', ...
    estado      estado_pago NOT NULL DEFAULT 'pendiente',
    referencia  TEXT,                              -- id de la pasarela
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_pagos_estado ON pagos (estado);

-- Sesiones de refresco (JWT refresh tokens)
CREATE TABLE sesiones (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    refresh_token TEXT NOT NULL UNIQUE,
    user_agent  TEXT,
    expira_en   TIMESTAMPTZ NOT NULL,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_sesiones_usuario ON sesiones (usuario_id);

-- ============================================================
-- 3. VISTAS Y FUNCIONES DE NEGOCIO
-- ============================================================

-- Vista: hospedaje + datos del anfitrión (para listados)
CREATE OR REPLACE VIEW v_hospedajes AS
SELECT h.*,
       u.nombre AS anfitrion_nombre,
       u.verificado AS anfitrion_verificado,
       ST_Y(h.ubicacion::geometry) AS lat,
       ST_X(h.ubicacion::geometry) AS lng
  FROM hospedajes h
  JOIN usuarios u ON u.id = h.anfitrion_id;

-- ⭐ Función: hospedajes dentro de un radio (metros) de una coordenada
CREATE OR REPLACE FUNCTION hospedajes_cerca(
    lat DOUBLE PRECISION,
    lng DOUBLE PRECISION,
    radio_m INTEGER DEFAULT 10000
) RETURNS TABLE (
    id UUID, titulo TEXT, tipo tipo_hospedaje, ciudad TEXT, barrio TEXT,
    precio_noche NUMERIC, rating NUMERIC, num_resenas INTEGER, distancia_m DOUBLE PRECISION
) LANGUAGE sql STABLE AS $$
    SELECT h.id, h.titulo, h.tipo, h.ciudad, h.barrio,
           h.precio_noche, h.rating, h.num_resenas,
           ST_Distance(h.ubicacion, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography) AS distancia_m
      FROM hospedajes h
     WHERE h.activo
       AND ST_DWithin(h.ubicacion, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography, radio_m)
     ORDER BY distancia_m;
$$;

-- ⭐ Función: hospedajes disponibles en un rango de fechas
CREATE OR REPLACE FUNCTION hospedajes_disponibles(
    f_desde DATE,
    f_hasta DATE
) RETURNS SETOF v_hospedajes LANGUAGE sql STABLE AS $$
    SELECT v.*
      FROM v_hospedajes v
     WHERE v.activo
       AND NOT EXISTS (
            SELECT 1 FROM reservas r
             WHERE r.hospedaje_id = v.id
               AND r.estado = 'confirmada'
               AND r.desde < f_hasta
               AND r.hasta > f_desde
       );
$$;

-- ⭐ Función: búsqueda combinada (texto + radio + fechas + tipo + convivencia)
CREATE OR REPLACE FUNCTION buscar_hospedajes(
    lat DOUBLE PRECISION DEFAULT NULL,
    lng DOUBLE PRECISION DEFAULT NULL,
    radio_m INTEGER DEFAULT NULL,
    f_desde DATE DEFAULT NULL,
    f_hasta DATE DEFAULT NULL,
    p_tipo tipo_hospedaje DEFAULT NULL,
    p_convivencia tipo_convivencia DEFAULT NULL,
    q TEXT DEFAULT NULL
) RETURNS TABLE (
    id UUID, titulo TEXT, tipo tipo_hospedaje, ciudad TEXT, barrio TEXT,
    precio_noche NUMERIC, rating NUMERIC, num_resenas INTEGER,
    distancia_m DOUBLE PRECISION
) LANGUAGE sql STABLE AS $$
    SELECT h.id, h.titulo, h.tipo, h.ciudad, h.barrio,
           h.precio_noche, h.rating, h.num_resenas,
           CASE WHEN lat IS NOT NULL THEN
                ST_Distance(h.ubicacion, ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography)
           END AS distancia_m
      FROM hospedajes h
     WHERE h.activo
       AND (p_tipo IS NULL OR h.tipo = p_tipo)
       AND (p_convivencia IS NULL OR h.convivencia = p_convivencia)
       AND (q IS NULL OR to_tsvector('spanish', h.titulo || ' ' || h.descripcion || ' ' || h.ciudad)
                          @@ plainto_tsquery('spanish', q))
       AND (lat IS NULL OR ST_DWithin(h.ubicacion,
                ST_SetSRID(ST_MakePoint(lng, lat), 4326)::geography, radio_m))
       AND (f_desde IS NULL OR NOT EXISTS (
            SELECT 1 FROM reservas r
             WHERE r.hospedaje_id = h.id AND r.estado = 'confirmada'
               AND r.desde < f_hasta AND r.hasta > f_desde))
     ORDER BY distancia_m NULLS LAST, h.rating DESC;
$$;

-- ============================================================
-- 4. AUDITORÍA (opcional, recomendado en producción)
-- ============================================================
CREATE TABLE IF NOT EXISTS auditoria (
    id         BIGSERIAL PRIMARY KEY,
    tabla      TEXT NOT NULL,
    operacion  TEXT NOT NULL,          -- INSERT / UPDATE / DELETE
    registro_id UUID,
    datos      JSONB,
    por_usuario UUID REFERENCES usuarios(id),
    creado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_auditoria_tabla ON auditoria (tabla, creado_en);
