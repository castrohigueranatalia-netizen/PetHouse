-- Corrige un error en el borrador de la política de privacidad ya cargado (ver
-- cargar-legal-borrador.sql): decía "15 días hábiles para consultas, 10 días hábiles para
-- reclamos", pero la Ley 1581 de 2012 es al revés — 10 días hábiles para consultas (Art. 14)
-- y 15 días hábiles para reclamos (Art. 15). Es un REPLACE puntual: si el texto ya no trae
-- esa frase (porque se editó desde el panel, o porque nunca se cargó ese borrador) esto no
-- cambia nada.
UPDATE documentos_legales
   SET contenido = REPLACE(
         contenido,
         'Vamos a responder dentro de los plazos que establece la ley (15 días hábiles para consultas, 10 días hábiles para reclamos).',
         'Vamos a responder dentro de los plazos que establece la ley (10 días hábiles para consultas, 15 días hábiles para reclamos).'
       ),
       actualizado_en = now()
 WHERE tipo = 'privacidad'
   AND contenido LIKE '%15 días hábiles para consultas, 10 días hábiles para reclamos%';
