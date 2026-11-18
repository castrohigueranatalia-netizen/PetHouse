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
}

