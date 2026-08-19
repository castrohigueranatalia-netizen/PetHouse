-- "Olvidé mi contraseña": código de 6 dígitos, enviado por correo, vigente 15 minutos.
-- Se guarda el HASH del código, no el código en sí (mismo principio que sesiones.refresh_token
-- desde el commit anterior) — una fuga de esta tabla no entrega códigos usables directamente.
CREATE TABLE IF NOT EXISTS restablecimientos_password (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    codigo_hash TEXT NOT NULL,
    expira_en   TIMESTAMPTZ NOT NULL,
    usado       BOOLEAN NOT NULL DEFAULT FALSE,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_restablecimientos_usuario ON restablecimientos_password (usuario_id);
