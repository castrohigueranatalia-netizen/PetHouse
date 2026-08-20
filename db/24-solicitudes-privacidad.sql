-- Solicitudes de privacidad: formulario dentro de la app para ejercer los derechos que ya
-- describe la política de privacidad (conocer, corregir o eliminar tus datos, o cualquier
-- otra duda/queja). El admin las ve y responde desde el panel — ver routes/admin.js.
--
-- `plazo_dias`/`vence_en` se calculan al crear la solicitud según la Ley 1581 de 2012:
--   Art. 14 (consultas, ej. "conocer mis datos")            → 10 días hábiles
--   Art. 15 (reclamos, ej. "corregir"/"eliminar"/"otra")     → 15 días hábiles
-- (ver lib/diasHabiles.js — el cálculo no descuenta festivos colombianos, solo fines de
-- semana, así que es una aproximación conservadora, no un cálculo legal exacto).
CREATE TABLE IF NOT EXISTS solicitudes_privacidad (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id     UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    categoria      TEXT NOT NULL CHECK (categoria IN ('conocer', 'corregir', 'eliminar', 'otra')),
    mensaje        TEXT NOT NULL,
    estado         TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'en_proceso', 'resuelta')),
    plazo_dias     INT NOT NULL,
    vence_en       TIMESTAMPTZ NOT NULL,
    respuesta      TEXT,
    respondido_en  TIMESTAMPTZ,
    creado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_solicitudes_privacidad_usuario ON solicitudes_privacidad (usuario_id);
CREATE INDEX IF NOT EXISTS idx_solicitudes_privacidad_estado ON solicitudes_privacidad (estado);
