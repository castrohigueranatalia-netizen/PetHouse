// ============================================================
// ARRIENDOS CARTAGENA API · Crea el esquema y aplica migraciones
// ------------------------------------------------------------
// Si la base de datos está vacía (recién creada, por ejemplo en
// Render), aplica db/01-esquema.sql y db/02-seed.sql automáticamente.
// Si ya tiene las tablas, no las vuelve a crear — pero sí aplica, en
// cada arranque, los pequeños cambios de esquema posteriores (como
// agregar el estado "pagada"), de forma segura para repetir.
// ============================================================
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { pool } from '../config.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const DB_DIR = path.join(__dirname, '..', '..', 'db')

export async function asegurarEsquema() {
  const { rows } = await pool.query("SELECT to_regclass('public.apartamentos') AS existe")
  if (!rows[0].existe) {
    console.log('⚙ Base de datos vacía: creando esquema y datos iniciales...')
    const esquema = fs.readFileSync(path.join(DB_DIR, '01-esquema.sql'), 'utf8')
    await pool.query(esquema)
    const seed = fs.readFileSync(path.join(DB_DIR, '02-seed.sql'), 'utf8')
    await pool.query(seed)
    console.log('✔ Esquema y datos iniciales creados (usuario y 7 apartamentos)')
  }

  await aplicarMigraciones()
}

// Cambios de esquema posteriores a la primera versión. Cada uno debe poder
// correr de nuevo sin romper nada (por eso las verificaciones "si ya existe,
// no hacer nada" antes de cada cambio).
async function aplicarMigraciones() {
  // Estado "pagada": una reserva confirmada con el pago ya recibido.
  await pool.query(`ALTER TYPE estado_reserva ADD VALUE IF NOT EXISTS 'pagada'`)

  // La restricción anti-doble-reserva debe bloquear tanto 'confirmada' como
  // 'pagada' (las dos ocupan el apartamento); se recrea solo si hace falta.
  const { rows } = await pool.query(
    `SELECT pg_get_constraintdef(oid) AS definicion FROM pg_constraint WHERE conname = 'chk_no_solape'`
  )
  const definicionActual = rows[0]?.definicion || ''
  if (definicionActual && !definicionActual.includes("'pagada'")) {
    console.log('⚙ Actualizando la restricción anti-doble-reserva para incluir "pagada"...')
    await pool.query(`ALTER TABLE reservas DROP CONSTRAINT chk_no_solape`)
    await pool.query(`
      ALTER TABLE reservas ADD CONSTRAINT chk_no_solape
        EXCLUDE USING gist (
          apartamento_id WITH =,
          daterange(checkin, checkout) WITH &&
        ) WHERE (estado IN ('confirmada', 'pagada'))
    `)
    console.log('✔ Restricción actualizada')
  }

  // Notificaciones push de pago pendiente (columna + tabla de suscripciones).
  await pool.query(`ALTER TABLE reservas ADD COLUMN IF NOT EXISTS recordatorio_pago_enviado_en TIMESTAMPTZ`)
  await pool.query(`
    CREATE TABLE IF NOT EXISTS push_suscripciones (
      id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      usuario_id  UUID NOT NULL REFERENCES usuarios(id) ON DELETE CASCADE,
      endpoint    TEXT NOT NULL UNIQUE,
      p256dh      TEXT NOT NULL,
      auth        TEXT NOT NULL,
      creado_en   TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)

  // Coordinación de limpieza: personal (niñas de limpieza) + tareas asignadas
  // por apartamento/fecha/hora. CREATE TYPE no admite "IF NOT EXISTS", por
  // eso se revisa antes en pg_type.
  const { rows: tipoLimpiezaExiste } = await pool.query(
    `SELECT 1 FROM pg_type WHERE typname = 'estado_limpieza'`
  )
  if (!tipoLimpiezaExiste.length) {
    await pool.query(`CREATE TYPE estado_limpieza AS ENUM ('pendiente', 'lista')`)
  }

  await pool.query(`
    CREATE TABLE IF NOT EXISTS personal_limpieza (
      id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      nombre     TEXT NOT NULL,
      telefono   TEXT,
      activo     BOOLEAN NOT NULL DEFAULT TRUE,
      creado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)

  await pool.query(`
    CREATE TABLE IF NOT EXISTS tareas_limpieza (
      id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
      apartamento_id  UUID NOT NULL REFERENCES apartamentos(id) ON DELETE CASCADE,
      personal_id     UUID REFERENCES personal_limpieza(id) ON DELETE SET NULL,
      fecha           DATE NOT NULL,
      hora            TIME,
      estado          estado_limpieza NOT NULL DEFAULT 'pendiente',
      notas           TEXT,
      creado_en       TIMESTAMPTZ NOT NULL DEFAULT now(),
      actualizado_en  TIMESTAMPTZ NOT NULL DEFAULT now()
    )
  `)
  await pool.query(`ALTER TABLE tareas_limpieza ADD COLUMN IF NOT EXISTS valor NUMERIC(10,2) CHECK (valor IS NULL OR valor >= 0)`)
  await pool.query(`CREATE INDEX IF NOT EXISTS idx_tareas_limpieza_fecha ON tareas_limpieza (fecha)`)
  await pool.query(`CREATE INDEX IF NOT EXISTS idx_tareas_limpieza_apartamento ON tareas_limpieza (apartamento_id)`)
  await pool.query(`DROP TRIGGER IF EXISTS trg_tareas_limpieza_actualizado_en ON tareas_limpieza`)
  await pool.query(`
    CREATE TRIGGER trg_tareas_limpieza_actualizado_en
      BEFORE UPDATE ON tareas_limpieza
      FOR EACH ROW EXECUTE FUNCTION tocar_actualizado_en()
  `)

  // Si la tabla personal_limpieza quedó vacía (base ya existente antes de
  // esta migración), se siembran las 5 niñas iniciales igual que en el seed.
  const { rows: personalExistente } = await pool.query('SELECT 1 FROM personal_limpieza LIMIT 1')
  if (!personalExistente.length) {
    await pool.query(`
      INSERT INTO personal_limpieza (nombre, telefono) VALUES
        ('María', '3000000001'), ('Carmen', '3000000002'), ('Luz Dary', '3000000003'),
        ('Yolanda', '3000000004'), ('Esperanza', '3000000005')
    `)
  }
}

