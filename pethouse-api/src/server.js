// ============================================================
// PETHOUSE API · Punto de entrada
// ============================================================
import app from './app.js'
import { PORT, pool } from './config.js'

async function iniciar() {
  // Comprueba la conexión a la base al arrancar
  try {
    await pool.query('SELECT postgis_version()')
    console.log('✔ Conectado a PostgreSQL + PostGIS')
  } catch (err) {
    console.error('✗ No se pudo conectar a la base de datos:', err.message)
    console.error('  Verifica DATABASE_URL (ver ../db/docker-compose.yml)')
    process.exit(1)
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🐾 Pethouse API escuchando en http://localhost:${PORT}`)
    console.log(`   Health:   GET  /health`)
    console.log(`   Auth:     POST /api/auth/login · /registro`)
    console.log(`   Búsqueda: GET  /api/hospedajes?ciudad=&tipo=&lat=&lng=&radio=`)
    console.log(`   IA:       GET  /api/ia/estado · POST /api/ia`)
  })
}

iniciar()
