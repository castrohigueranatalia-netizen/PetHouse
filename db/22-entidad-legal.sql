-- Datos de la empresa y los documentos legales (política de privacidad, términos de uso)
-- — editables desde el panel de admin (admin-web/), sin tener que tocar código ni
-- redesplegar cada vez que cambie una palabra. La app de iOS lee `documentos_legales` en
-- modo solo lectura (GET /api/legal/:tipo, sin autenticación) para mostrárselos al usuario
-- — requisito de la App Store (Guideline 5.1.1) y de la Ley 1581 de 2012.

-- Fila única (singleton, id siempre 1) — no tiene sentido más de una "entidad legal".
CREATE TABLE IF NOT EXISTS entidad_legal (
    id                 INT PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    nombre_legal       TEXT,
    nit                TEXT,
    domicilio          TEXT,
    correo_contacto    TEXT,
    telefono_contacto  TEXT,
    actualizado_en     TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO entidad_legal (id) VALUES (1) ON CONFLICT (id) DO NOTHING;

CREATE TABLE IF NOT EXISTS documentos_legales (
    tipo           TEXT PRIMARY KEY CHECK (tipo IN ('privacidad', 'terminos')),
    contenido      TEXT NOT NULL DEFAULT '',
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
INSERT INTO documentos_legales (tipo, contenido) VALUES
  ('privacidad', ''),
  ('terminos', '')
ON CONFLICT (tipo) DO NOTHING;
