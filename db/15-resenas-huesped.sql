-- ============================================================
-- PETHOUSE · Reseñas del huésped (calificación del anfitrión al huésped/mascota)
-- ------------------------------------------------------------
-- Antes solo el huésped podía calificar el hospedaje (tabla `resenas`, ver 01-esquema.sql).
-- Ahora el anfitrión también puede calificar al huésped después de una reserva —mismo
-- patrón exacto, espejado: tabla propia, trigger que mantiene rating/num_resenas en
-- `usuarios`, una reseña por reserva.
--
-- El anfitrión ve la evaluación y los comentarios del huésped al revisar una solicitud de
-- reserva (antes de aceptar o rechazar) — ver `usuario_rating`/`usuario_num_resenas` en
-- GET /api/hospedajes/:id/reservas (routes/hospedajes.js) y GET /api/usuarios/:id/resenas
-- (routes/usuarios.js, nuevo) para el detalle completo.
--
-- Aplicar después de 14-fotos-mascota.sql:
--   psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -f 15-resenas-huesped.sql
-- ============================================================

ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS rating NUMERIC(3,2) NOT NULL DEFAULT 0 CHECK (rating BETWEEN 0 AND 5);
ALTER TABLE usuarios ADD COLUMN IF NOT EXISTS num_resenas INTEGER NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS resenas_usuario (
    id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    reserva_id   UUID NOT NULL UNIQUE REFERENCES reservas(id) ON DELETE CASCADE,
    autor_id     UUID NOT NULL REFERENCES usuarios(id) ON DELETE RESTRICT,  -- el anfitrión que califica
    usuario_id   UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,   -- el huésped calificado
    rating       SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
    titulo       TEXT,
    texto        TEXT,
    creado_en    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_resenas_usuario_usuario ON resenas_usuario (usuario_id);

CREATE OR REPLACE FUNCTION actualizar_rating_usuario() RETURNS TRIGGER AS $$
BEGIN
    UPDATE usuarios u
       SET rating      = COALESCE((SELECT ROUND(AVG(rating)::numeric, 2) FROM resenas_usuario WHERE usuario_id = COALESCE(NEW.usuario_id, OLD.usuario_id)), 0),
           num_resenas = COALESCE((SELECT COUNT(*) FROM resenas_usuario WHERE usuario_id = COALESCE(NEW.usuario_id, OLD.usuario_id)), 0)
     WHERE u.id = COALESCE(NEW.usuario_id, OLD.usuario_id);
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_rating_resena_usuario ON resenas_usuario;
CREATE TRIGGER trg_rating_resena_usuario
    AFTER INSERT OR UPDATE OR DELETE ON resenas_usuario
    FOR EACH ROW EXECUTE FUNCTION actualizar_rating_usuario();
