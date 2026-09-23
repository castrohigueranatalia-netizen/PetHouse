-- ============================================================
-- PETHOUSE · El anfitrión puede responder públicamente a una reseña de su hospedaje
-- ------------------------------------------------------------
-- Solo aplica a `resenas` (huésped → hospedaje) — el anfitrión es el sujeto de esa reseña,
-- no el autor, así que tiene sentido darle derecho a réplica pública debajo. No aplica a
-- `resenas_usuario` (anfitrión → huésped, ver 15-resenas-huesped.sql): ahí el anfitrión ya
-- es quien escribe, no hay a quién "responderle".
--
-- Una sola respuesta por reseña (no un hilo de comentarios) — se sobrescribe si el
-- anfitrión la edita, igual que editar cualquier otro campo.
--
-- Aplicar después de 32-fotos-chat.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 33-respuesta-resena.sql
-- ============================================================

ALTER TABLE resenas ADD COLUMN IF NOT EXISTS respuesta_anfitrion TEXT;
ALTER TABLE resenas ADD COLUMN IF NOT EXISTS respuesta_en TIMESTAMPTZ;
