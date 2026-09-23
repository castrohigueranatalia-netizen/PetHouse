-- ============================================================
-- PETHOUSE · Verificación de seguridad + preferencias de anfitrión
-- ------------------------------------------------------------
-- Antes de poder publicar hospedajes, un usuario que "se convierte en anfitrión" pasa por
-- dos pasos: 1) verificación de identidad/seguridad (nombre legal, cédula, certificado de
-- antecedentes, referencias, fotos de la persona y de la vivienda) y 2) preferencias de
-- cuidado (qué especie, por días u horas, qué tamaño de mascota).
--
-- No hay panel de administración en este MVP para aprobar/rechazar verificaciones — el
-- estado queda en 'pendiente' desde el envío (self-serve), visible en la app, pero NO
-- bloquea el uso de las funciones de anfitrión todavía (soloAnfitrion sigue autorizando
-- por usuarios.es_anfitrion, que esta verificación activa al enviarse). Cuando exista un
-- flujo de revisión real, 'estado' ya está listo para usarse como el gate de verdad.
--
-- Aplicar después de 05-multi-rol.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 06-verificacion-anfitrion.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS verificaciones_anfitrion (
    id                        UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id                UUID NOT NULL UNIQUE REFERENCES usuarios(id) ON DELETE CASCADE,
    nombre_legal              TEXT NOT NULL,
    cedula                    TEXT NOT NULL,
    certificado_policial_url  TEXT NOT NULL,
    referencias               TEXT[] NOT NULL DEFAULT '{}',
    fotos_persona             TEXT[] NOT NULL DEFAULT '{}',
    fotos_vivienda            TEXT[] NOT NULL DEFAULT '{}',
    estado                    TEXT NOT NULL DEFAULT 'pendiente'
                                CHECK (estado IN ('pendiente', 'aprobado', 'rechazado')),
    creado_en                 TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en            TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_verificaciones_usuario ON verificaciones_anfitrion (usuario_id);

CREATE TABLE IF NOT EXISTS preferencias_anfitrion (
    usuario_id      UUID PRIMARY KEY REFERENCES usuarios(id) ON DELETE CASCADE,
    -- Multi-selección: un anfitrión puede aceptar perros Y gatos, días Y horas, etc.
    especies        TEXT[] NOT NULL DEFAULT '{}' CHECK (especies <@ ARRAY['perro','gato']),
    modalidades     TEXT[] NOT NULL DEFAULT '{}' CHECK (modalidades <@ ARRAY['dias','horas']),
    tamanos         TEXT[] NOT NULL DEFAULT '{}' CHECK (tamanos <@ ARRAY['pequeno','mediano','grande']),
    actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
);
