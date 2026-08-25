-- ============================================================
-- ARRIENDOS CARTAGENA · Esquema PostgreSQL
-- ------------------------------------------------------------
-- Base de datos del control de reservas de los apartamentos
-- (reemplazo del Excel). Requiere PostgreSQL 14+.
--
-- Para levantar una base local lista:
--   docker compose up -d        (ver docker-compose.yml)
--   psql -h localhost -p 5433 -U arriendos -d arriendos -f 01-esquema.sql
-- ============================================================

-- ------------------------------------------------------------
-- 0. EXTENSIONES
-- ------------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto;    -- gen_random_uuid() + crypt() para el seed
CREATE EXTENSION IF NOT EXISTS btree_gist;  -- exclusión de fechas solapadas

-- ------------------------------------------------------------
-- 1. TIPOS ENUM
-- ------------------------------------------------------------
CREATE TYPE fuente_reserva AS ENUM ('booking', 'airbnb', 'whatsapp', 'directo', 'otro');
CREATE TYPE estado_reserva AS ENUM ('confirmada', 'pendiente', 'cancelada');

-- ------------------------------------------------------------
-- 2. USUARIOS
-- ------------------------------------------------------------
-- Uso interno y familiar: quien tenga cuenta puede administrar
-- todos los apartamentos (no hay marketplace de terceros aquí).
CREATE TABLE usuarios (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre        TEXT NOT NULL,
    email         TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    creado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- 3. APARTAMENTOS
-- ------------------------------------------------------------
CREATE TABLE apartamentos (
    id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    nombre             TEXT NOT NULL,                  -- ej. "Apto 301 - Bocagrande"
    descripcion        TEXT,
    capacidad          SMALLINT NOT NULL DEFAULT 2 CHECK (capacidad > 0),
    precio_noche_base  NUMERIC(10,2) CHECK (precio_noche_base IS NULL OR precio_noche_base >= 0),

    -- Sincronización de calendario con Booking/Airbnb (vía iCal, no requiere API):
    ical_url_importar  TEXT,                            -- URL "Exportar calendario" que da Booking/Airbnb (la leemos)
    ical_token         UUID NOT NULL DEFAULT gen_random_uuid(), -- token secreto de NUESTRA url de exportación
    ical_ultima_sync   TIMESTAMPTZ,
    ical_ultimo_error  TEXT,

    activo             BOOLEAN NOT NULL DEFAULT TRUE,
    creado_en          TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- ------------------------------------------------------------
-- 4. RESERVAS
-- ------------------------------------------------------------
CREATE TABLE reservas (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    apartamento_id  UUID NOT NULL REFERENCES apartamentos(id) ON DELETE RESTRICT,

    huesped_nombre    TEXT,
    huesped_telefono  TEXT,
    checkin           DATE NOT NULL,
    checkout          DATE NOT NULL,
    noches            SMALLINT GENERATED ALWAYS AS (checkout - checkin) STORED,
    num_huespedes     SMALLINT NOT NULL DEFAULT 1 CHECK (num_huespedes >= 1),
    precio_total      NUMERIC(10,2) CHECK (precio_total IS NULL OR precio_total >= 0),

    fuente          fuente_reserva NOT NULL DEFAULT 'directo',
    estado          estado_reserva NOT NULL DEFAULT 'confirmada',
    notas           TEXT,

    -- Cuando la reserva viene de la sincronización iCal guardamos el UID del
    -- evento de origen, tanto para no duplicarla en cada sincronización como
    -- para poder marcarla 'cancelada' si el evento desaparece del calendario.
    ical_uid        TEXT,

    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now(),

    CONSTRAINT chk_fechas CHECK (checkout > checkin),
    CONSTRAINT uq_ical_uid UNIQUE (apartamento_id, ical_uid)
);

CREATE INDEX idx_reservas_apartamento ON reservas (apartamento_id);
CREATE INDEX idx_reservas_fechas      ON reservas (checkin, checkout);

-- Evita dobles reservas: no permite dos reservas CONFIRMADAS del mismo
-- apartamento con fechas que se solapen (checkout es fecha de salida,
-- así que dos reservas que "se tocan" en ese día no se consideran solapadas).
ALTER TABLE reservas ADD CONSTRAINT chk_no_solape
    EXCLUDE USING gist (
        apartamento_id WITH =,
        daterange(checkin, checkout) WITH &&
    ) WHERE (estado = 'confirmada');

-- Mantiene actualizado_en al día en cada UPDATE
CREATE OR REPLACE FUNCTION tocar_actualizado_en() RETURNS trigger AS $$
BEGIN
    NEW.actualizado_en = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_reservas_actualizado_en
    BEFORE UPDATE ON reservas
    FOR EACH ROW EXECUTE FUNCTION tocar_actualizado_en();
