-- ============================================================
-- PETHOUSE · Denuncias (reportar anfitriones, usuarios y mensajes) + bloqueo de cuentas
-- ------------------------------------------------------------
-- Se llama "denuncias", no "reportes", para no chocar con /api/admin/reportes/* (los
-- informes financieros de comisión, ver 27-comision.sql) — son dos cosas distintas que ya
-- comparten esa palabra en el panel.
--
-- Cualquier usuario logueado puede denunciar a otro (un anfitrión desde su hospedaje, a
-- cualquier usuario desde donde aparezca — ej. una solicitud de reserva, un chat — o un
-- mensaje puntual del chat). Todas las denuncias caen en una cola para el administrador
-- (mismo patrón que solicitudes_privacidad/solicitudes_identidad_password): él la revisa,
-- deja una nota y, si corresponde, bloquea la cuenta denunciada.
--
-- Aplicar después de 29-mas-localidades.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 30-denuncias.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS denuncias (
    id                    UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    denunciante_id        UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    usuario_denunciado_id UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    -- Solo describe DESDE DÓNDE se hizo la denuncia (perfil de anfitrión, de cualquier
    -- usuario, o un mensaje puntual) — las tres siempre apuntan a un usuario_denunciado_id;
    -- 'mensaje' además trae mensaje_id/mensaje_texto.
    tipo                  TEXT NOT NULL CHECK (tipo IN ('anfitrion', 'usuario', 'mensaje')),
    motivo                TEXT NOT NULL
                            CHECK (motivo IN ('spam', 'acoso', 'contenido_inapropiado', 'informacion_falsa', 'fraude', 'otro')),
    comentario            TEXT,
    mensaje_id            UUID REFERENCES mensajes(id) ON DELETE SET NULL,
    -- Copia del texto del mensaje AL MOMENTO de denunciar: si el mensaje o la conversación
    -- se borran después, el admin igual puede ver qué se denunció (mismo criterio que
    -- `pagos.comision_porcentaje` guardando el % vigente en vez de solo apuntar a la fila
    -- que puede cambiar después).
    mensaje_texto         TEXT,
    hospedaje_id          UUID REFERENCES hospedajes(id) ON DELETE SET NULL,
    estado                TEXT NOT NULL DEFAULT 'pendiente' CHECK (estado IN ('pendiente', 'revisada', 'descartada')),
    nota_admin            TEXT,
    creado_en             TIMESTAMPTZ NOT NULL DEFAULT now(),
    resuelto_en           TIMESTAMPTZ,
    CONSTRAINT chk_denuncia_distintos CHECK (denunciante_id <> usuario_denunciado_id)
);

CREATE INDEX IF NOT EXISTS idx_denuncias_estado ON denuncias (estado);
CREATE INDEX IF NOT EXISTS idx_denuncias_denunciado ON denuncias (usuario_denunciado_id);

-- Bloqueo de cuentas: lo activa un admin al revisar una denuncia (o desde la ficha del
-- usuario en el panel). Un usuario bloqueado no puede iniciar sesión, pierde de inmediato
-- todas sus sesiones activas (ver POST /admin/usuarios/:id/bloquear) y sus hospedajes dejan
-- de aparecer en Buscar — ver pethouse-api/src/middleware/middleware.js y routes/hospedajes.js.
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS bloqueado BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS bloqueado_motivo TEXT;
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS bloqueado_en TIMESTAMPTZ;
