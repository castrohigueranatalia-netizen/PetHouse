-- ============================================================
-- PETHOUSE · Centro de notificaciones (campana con historial completo)
-- ------------------------------------------------------------
-- Hasta acá, los avisos ("tu solicitud se resolvió", "te llegó una reserva") eran
-- puramente efímeros: un `.alert` que aparecía una vez al abrir la app y, al cerrarlo, se
-- perdía para siempre (solo quedaba un booleano `notificado`/`notificado_anfitrion` en la
-- fila de origen — ver 10/12/17-*.sql). No había forma de volver a ver un aviso ya visto.
--
-- Esta tabla es un historial real, aparte de esos booleanos (que se dejan tal cual, siguen
-- alimentando el `.alert` instantáneo de siempre) — cada evento importante ADEMÁS inserta
-- una fila acá, para que la campana pueda mostrar tanto las nuevas como las viejas.
--
-- `reserva_id`/`hospedaje_id` son opcionales y sueltos (sin FK) a propósito: si la reserva o
-- el hospedaje se llegara a borrar más adelante, la notificación sigue existiendo como
-- registro histórico en vez de desaparecer o bloquear el borrado.
--
-- Aplicar después de 18-ocultar-reserva.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 19-notificaciones.sql
-- ============================================================

CREATE TABLE IF NOT EXISTS notificaciones (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
    tipo        TEXT NOT NULL, -- 'verificacion_resuelta' | 'reserva_resuelta' | 'solicitud_nueva'
    titulo      TEXT NOT NULL,
    mensaje     TEXT NOT NULL,
    leida       BOOLEAN NOT NULL DEFAULT FALSE,
    reserva_id  UUID,
    hospedaje_id UUID,
    creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_notificaciones_usuario ON notificaciones (usuario_id, creado_en DESC);
