-- Respaldo de "olvidé mi contraseña" cuando el correo no llega: el usuario sube una foto
-- de su cédula (sin haber iniciado sesión — para eso es este flujo) y un admin la revisa a
-- mano contra el nombre de la cuenta. Si corresponde, el admin genera un PIN que el usuario
-- usa en la MISMA pantalla de "código de 6 dígitos" (ver POST /auth/restablecer-password —
-- el PIN se guarda en restablecimientos_password, la tabla que ya existía, así que no hace
-- falta una pantalla nueva para "canjearlo").
--
-- La foto va a uploads-privado/ (misma carpeta y mismo mecanismo de URL firmada que las
-- fotos de verificación de anfitrión — ver lib/urlsPrivadas.js), nunca a uploads/ público.
CREATE TABLE IF NOT EXISTS solicitudes_identidad_password (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email           TEXT NOT NULL,
    -- Puede quedar NULL si el correo escrito no coincide con ninguna cuenta — el admin lo
    -- ve igual (con una advertencia) en vez de que la solicitud desaparezca sin explicación.
    usuario_id      UUID REFERENCES usuarios(id) ON DELETE CASCADE,
    foto_cedula_url TEXT NOT NULL,
    estado          TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'aprobada', 'rechazada')),
    creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
    revisado_en     TIMESTAMPTZ
);
CREATE INDEX IF NOT EXISTS idx_solicitudes_identidad_estado ON solicitudes_identidad_password (estado);
CREATE INDEX IF NOT EXISTS idx_solicitudes_identidad_usuario ON solicitudes_identidad_password (usuario_id);
