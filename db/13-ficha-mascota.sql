-- ============================================================
-- PETHOUSE · Ficha completa de la mascota
-- ------------------------------------------------------------
-- Antes `mascotas` solo tenía nombre/especie/raza/peso/vacunas/notas. El anfitrión, al
-- recibir una solicitud de reserva, necesita evaluar si puede aceptar a esa mascota — para
-- eso le faltaban edad, tamaño y si necesita medicamentos (antes solo había "notas" en
-- texto libre, sin un campo explícito para esto último).
--
-- `tamano` usa los mismos valores que `preferencias_anfitrion.tamanos`
-- (06-verificacion-anfitrion.sql: 'pequeno'/'mediano'/'grande') — mismo vocabulario en toda
-- la app, así el filtro de preferencias del anfitrión y la ficha de la mascota hablan el
-- mismo idioma.
--
-- `notas` se sigue usando para el detalle libre (qué medicamento, dosis, cuidados
-- especiales) cuando `necesita_medicamentos = TRUE` — no se agrega una columna nueva para
-- eso, ya existía y es de texto libre por diseño.
--
-- Aplicar después de 12-notificacion-reserva-resuelta.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 13-ficha-mascota.sql
-- ============================================================

ALTER TABLE mascotas ADD COLUMN IF NOT EXISTS edad SMALLINT CHECK (edad IS NULL OR (edad >= 0 AND edad <= 40));
ALTER TABLE mascotas ADD COLUMN IF NOT EXISTS tamano TEXT CHECK (tamano IS NULL OR tamano IN ('pequeno', 'mediano', 'grande'));
ALTER TABLE mascotas ADD COLUMN IF NOT EXISTS necesita_medicamentos BOOLEAN NOT NULL DEFAULT FALSE;
