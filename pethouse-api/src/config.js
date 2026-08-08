// ============================================================
// PETHOUSE API · Configuración y pool de PostgreSQL/PostGIS
// ============================================================
import 'dotenv/config'
import pg from 'pg'

export const PORT = Number(process.env.PORT || 3001)
export const JWT_SECRET = process.env.JWT_SECRET || 'cambia-este-secreto-en-produccion'
export const GEMINI_KEY = process.env.GEMINI_API_KEY || ''
export const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash'

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgres://pethouse:pethouse@localhost:5432/pethouse',
  ssl: process.env.PGSSLMODE === 'require' ? { rejectUnauthorized: false } : undefined,
  max: 10,
  idleTimeoutMillis: 30000
})

pool.on('error', (err) => console.error('Error inesperado en el pool:', err.message))
