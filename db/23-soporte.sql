-- Soporte: buzón real dentro de la app — un usuario escribe un ticket, un admin lo ve y
-- responde desde el panel (admin-web/), con hilo de mensajes tipo conversación (mismo
-- patrón de dos tablas que conversaciones/mensajes del chat entre huésped y anfitrión,
-- ver db/01-esquema.sql).
CREATE TABLE IF NOT EXISTS tickets_soporte (
    id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id     UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    asunto         TEXT NOT NULL,
    estado         TEXT NOT NULL DEFAULT 'abierto' CHECK (estado IN ('abierto', 'resuelto')),
    creado_en      TIMESTAMPTZ NOT NULL DEFAULT now(),
    actualizado_en TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_tickets_usuario ON tickets_soporte (usuario_id);
CREATE INDEX IF NOT EXISTS idx_tickets_estado ON tickets_soporte (estado);

CREATE TABLE IF NOT EXISTS mensajes_soporte (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    ticket_id   UUID NOT NULL REFERENCES tickets_soporte(id) ON DELETE CASCADE,
    -- `es_admin`, no `remitente_id`: quien responde del lado de soporte no necesita ser
    -- siempre la misma cuenta de administrador — solo importa que la respuesta es "del
    -- equipo de PetHouse", no de qué admin puntual.
    es_admin    BOOLEAN NOT NULL DEFAULT FALSE,
    texto       TEXT NOT NULL,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_mensajes_soporte_ticket ON mensajes_soporte (ticket_id, creado_en);
