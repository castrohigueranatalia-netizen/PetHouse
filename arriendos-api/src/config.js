// ============================================================
// ARRIENDOS CARTAGENA API · Configuración y pool de PostgreSQL
// ============================================================
import 'dotenv/config'
import pg from 'pg'

export const PORT = Number(process.env.PORT || 3002)
export const JWT_SECRET = process.env.JWT_SECRET || 'cambia-este-secreto-en-produccion'
export const SYNC_INTERVAL_MIN = Number(process.env.SYNC_INTERVAL_MIN ?? 30)
export const PUBLIC_URL = (process.env.PUBLIC_URL || `http://localhost:${PORT}`).replace(/\/$/, '')

// Notificaciones push de "falta el pago" (ver src/services/notificacionesPago.js)
export const VAPID_PUBLIC_KEY = process.env.VAPID_PUBLIC_KEY || ''
export const VAPID_PRIVATE_KEY = process.env.VAPID_PRIVATE_KEY || ''
export const VAPID_SUBJECT = process.env.VAPID_SUBJECT || 'mailto:soporte@arriendoscartagena.com'
export const RECORDATORIO_PAGO_DIAS = Number(process.env.RECORDATORIO_PAGO_DIAS ?? 3)

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgres://arriendos:arriendos@localhost:5433/arriendos',
  ssl: process.env.PGSSLMODE === 'require' ? { rejectUnauthorized: false } : undefined,
  max: 10,
  idleTimeoutMillis: 30000
})

pool.on('error', (err) => console.error('Error inesperado en el pool:', err.message))
