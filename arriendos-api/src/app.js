// ============================================================
// ARRIENDOS CARTAGENA API · Aplicación Express
// ============================================================
import path from 'node:path'
import { fileURLToPath } from 'node:url'
import express from 'express'
import cors from 'cors'

import authRoutes from './routes/auth.js'
import apartamentosRoutes from './routes/apartamentos.js'
import reservasRoutes from './routes/reservas.js'
import icalRoutes from './routes/ical.js'
import asistenteRoutes from './routes/asistente.js'
import pushRoutes from './routes/push.js'
import personalLimpiezaRoutes from './routes/personalLimpieza.js'
import tareasLimpiezaRoutes from './routes/tareasLimpieza.js'
import { manejadorErrores, noEncontrado } from './middleware/middleware.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))

const app = express()

app.use(cors())
app.use(express.json({ limit: '1mb' }))

app.get('/health', (_req, res) => res.json({ ok: true, servicio: 'arriendos-api', hora: new Date().toISOString() }))

app.use('/api/auth', authRoutes)
app.use('/api/apartamentos', apartamentosRoutes)
app.use('/api/apartamentos', icalRoutes)   // GET /:id/calendario.ics · POST /:id/sincronizar
app.use('/api/reservas', reservasRoutes)
app.use('/api/asistente', asistenteRoutes)
app.use('/api/push', pushRoutes)
app.use('/api/personal-limpieza', personalLimpiezaRoutes)
app.use('/api/tareas-limpieza', tareasLimpiezaRoutes)

// Frontend (página autocontenida) servida desde /public
app.use(express.static(path.join(__dirname, '..', 'public')))

app.use('/api', noEncontrado)
app.use(manejadorErrores)

export default app
