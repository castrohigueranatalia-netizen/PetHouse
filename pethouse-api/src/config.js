// ============================================================
// PETHOUSE API · Configuración y pool de PostgreSQL/PostGIS
// ============================================================
import 'dotenv/config'
import crypto from 'node:crypto'
import pg from 'pg'

export const PORT = Number(process.env.PORT || 3001)

// El JWT_SECRET ya NO tiene un valor por defecto conocido/público (ver
// ARCHITECTURE_AUDIT.md §6, gap bloqueante #2): antes, si faltaba la variable de entorno,
// la API firmaba tokens con el string literal 'cambia-este-secreto-en-produccion', que
// cualquiera puede leer en este mismo repo — un atacante podía forjar JWT válidos.
// - En producción, faltar JWT_SECRET ahora es un error fatal: el servidor no arranca
//   (mejor un arranque fallido y visible que tokens firmados con un secreto público).
// - En desarrollo, para no romper el flujo de `npm start` sin `.env`, se genera un
//   secreto aleatorio en memoria por arranque (con aviso). Es intencional que esto invalide
//   las sesiones existentes al reiniciar el servidor en dev — nunca debe pasar en prod.
function resolverJwtSecret() {
  if (process.env.JWT_SECRET) return process.env.JWT_SECRET
  if (process.env.NODE_ENV === 'production') {
    throw new Error(
      'JWT_SECRET es obligatorio en producción (NODE_ENV=production) y no está configurado. ' +
      'Define la variable de entorno antes de arrancar — ver pethouse-api/.env.example.'
    )
  }
  const generado = crypto.randomBytes(48).toString('hex')
  console.warn(
    '⚠ JWT_SECRET no está configurado. Se generó uno aleatorio SOLO para esta ejecución ' +
    '(las sesiones existentes se invalidan al reiniciar). Define JWT_SECRET en .env antes de desplegar.'
  )
  return generado
}
export const JWT_SECRET = resolverJwtSecret()

export const GEMINI_KEY = process.env.GEMINI_API_KEY || ''
export const GEMINI_MODEL = process.env.GEMINI_MODEL || 'gemini-2.0-flash'

// CORS restringido (ver ARCHITECTURE_AUDIT.md §6, gap bloqueante #3): lista de orígenes
// separados por coma en ALLOWED_ORIGINS (ej. "https://pethouse.co,https://www.pethouse.co").
// Sin configurar, se mantiene abierto (`undefined` → cors() permite cualquier origen) para
// no romper el desarrollo local/las apps nativas (que no envían Origin), pero se avisa.
export const ALLOWED_ORIGINS = process.env.ALLOWED_ORIGINS
  ? process.env.ALLOWED_ORIGINS.split(',').map((o) => o.trim()).filter(Boolean)
  : null
if (!ALLOWED_ORIGINS) {
  console.warn(
    '⚠ ALLOWED_ORIGINS no está configurado: CORS acepta cualquier origen. ' +
    'Defínelo antes de desplegar a producción (ver pethouse-api/.env.example).'
  )
}

// Base pública para construir URLs de archivos subidos (ver src/routes/subidas.js).
// Ej. "https://api.pethouse.co" → https://api.pethouse.co/uploads/archivo.jpg
export const PUBLIC_BASE_URL = process.env.PUBLIC_BASE_URL || `http://localhost:${PORT}`

export const pool = new pg.Pool({
  connectionString: process.env.DATABASE_URL || 'postgres://pethouse:pethouse@localhost:5432/pethouse',
  ssl: process.env.PGSSLMODE === 'require' ? { rejectUnauthorized: false } : undefined,
  max: 10,
  idleTimeoutMillis: 30000
})

pool.on('error', (err) => console.error('Error inesperado en el pool:', err.message))
