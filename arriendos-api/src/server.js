// ============================================================
// ARRIENDOS CARTAGENA API · Punto de entrada
// ============================================================
import cron from 'node-cron'
import app from './app.js'
import { PORT, SYNC_INTERVAL_MIN, pool } from './config.js'
import { sincronizarTodos } from './services/icalSync.js'

async function iniciar() {
  // Comprueba la conexión a la base al arrancar
  try {
    await pool.query('SELECT 1')
    console.log('✔ Conectado a PostgreSQL')
  } catch (err) {
    console.error('✗ No se pudo conectar a la base de datos:', err.message)
    console.error('  Verifica DATABASE_URL (ver ../db/docker-compose.yml)')
    process.exit(1)
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`🏠 Arriendos Cartagena API escuchando en http://localhost:${PORT}`)
    console.log(`   App:      GET  /`)
    console.log(`   Health:   GET  /health`)
    console.log(`   Auth:     POST /api/auth/login`)
    console.log(`   Reservas: GET  /api/reservas?apartamento_id=&desde=&hasta=`)
  })

  if (SYNC_INTERVAL_MIN > 0) {
    // Una sincronización al arrancar y luego cada SYNC_INTERVAL_MIN minutos
    sincronizarTodos().catch((err) => console.error('Sincronización inicial falló:', err.message))
    cron.schedule(`*/${SYNC_INTERVAL_MIN} * * * *`, () => {
      sincronizarTodos().catch((err) => console.error('Sincronización periódica falló:', err.message))
    })
    console.log(`   🔄 Sincronización automática de iCal cada ${SYNC_INTERVAL_MIN} min`)
  } else {
    console.log('   🔄 Sincronización automática desactivada (SYNC_INTERVAL_MIN=0)')
  }
}

iniciar()
