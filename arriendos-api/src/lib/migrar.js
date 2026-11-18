// ============================================================
// ARRIENDOS CARTAGENA API · Crea el esquema solo (primer arranque)
// ------------------------------------------------------------
// Si la base de datos está vacía (recién creada, por ejemplo en
// Render), aplica db/01-esquema.sql y db/02-seed.sql automáticamente.
// Si ya tiene las tablas, no hace nada. Así no hace falta correr SQL
// a mano cuando se despliega en un servidor nuevo.
// ============================================================
import fs from 'node:fs'
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import { pool } from '../config.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
const DB_DIR = path.join(__dirname, '..', '..', 'db')

export async function asegurarEsquema() {
  const { rows } = await pool.query("SELECT to_regclass('public.apartamentos') AS existe")
  if (rows[0].existe) return // ya está inicializada

  console.log('⚙ Base de datos vacía: creando esquema y datos iniciales...')
  const esquema = fs.readFileSync(path.join(DB_DIR, '01-esquema.sql'), 'utf8')
  await pool.query(esquema)
  const seed = fs.readFileSync(path.join(DB_DIR, '02-seed.sql'), 'utf8')
  await pool.query(seed)
  console.log('✔ Esquema y datos iniciales creados (usuario y 7 apartamentos)')
}
