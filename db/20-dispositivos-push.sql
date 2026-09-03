-- Tokens de dispositivo para notificaciones push (APNs). Un usuario puede tener
-- varios dispositivos; un token pertenece a un solo usuario a la vez (si se
-- reinstala la app con otra cuenta, el mismo token se reasigna al nuevo usuario
-- vía UPSERT en vez de acumular filas huérfanas).
CREATE TABLE IF NOT EXISTS dispositivos_push (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    token       TEXT NOT NULL UNIQUE,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_dispositivos_push_usuario ON dispositivos_push (usuario_id);
