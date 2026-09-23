-- ============================================================
-- PETHOUSE · Fotos en el chat
-- ------------------------------------------------------------
-- Hasta ahora los mensajes eran solo texto (`mensajes.texto TEXT NOT NULL`). En pet-sitting
-- es muy natural mandar una foto ("así quedó el patio", "mira cómo se porta") — se agrega
-- `foto_url` y `texto` pasa a ser opcional (un mensaje puede ser SOLO una foto, sin pie de
-- foto), con un CHECK que exige al menos uno de los dos.
--
-- Aplicar después de 31-denuncias-resenas.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 32-fotos-chat.sql
-- ============================================================

ALTER TABLE mensajes ALTER COLUMN texto DROP NOT NULL;
ALTER TABLE mensajes ADD COLUMN IF NOT EXISTS foto_url TEXT;

ALTER TABLE mensajes DROP CONSTRAINT IF EXISTS chk_mensajes_contenido;
ALTER TABLE mensajes ADD CONSTRAINT chk_mensajes_contenido CHECK (texto IS NOT NULL OR foto_url IS NOT NULL);
