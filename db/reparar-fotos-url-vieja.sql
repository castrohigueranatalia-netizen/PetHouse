-- Uso único: convierte URLs de fotos guardadas como absolutas (con la IP de red de ese
-- momento, ej. "http://192.168.1.5:3001/uploads/x.jpg") a relativas ("/uploads/x.jpg").
-- Necesario una sola vez para fotos subidas ANTES del arreglo en subidas.js — las subidas
-- desde ahora ya se guardan relativas y no necesitan esto.
UPDATE usuarios SET foto_url = regexp_replace(foto_url, '^https?://[^/]+', '')
  WHERE foto_url ~ '^https?://';

UPDATE mascotas SET fotos = ARRAY(SELECT regexp_replace(f, '^https?://[^/]+', '') FROM unnest(fotos) AS f)
  WHERE fotos IS NOT NULL AND array_length(fotos, 1) > 0;

UPDATE hospedajes SET fotos = ARRAY(SELECT regexp_replace(f, '^https?://[^/]+', '') FROM unnest(fotos) AS f)
  WHERE fotos IS NOT NULL AND array_length(fotos, 1) > 0;

UPDATE verificaciones_anfitrion SET
  fotos_persona = ARRAY(SELECT regexp_replace(f, '^https?://[^/]+', '') FROM unnest(fotos_persona) AS f),
  fotos_vivienda = ARRAY(SELECT regexp_replace(f, '^https?://[^/]+', '') FROM unnest(fotos_vivienda) AS f)
  WHERE (fotos_persona IS NOT NULL AND array_length(fotos_persona, 1) > 0)
     OR (fotos_vivienda IS NOT NULL AND array_length(fotos_vivienda, 1) > 0);
