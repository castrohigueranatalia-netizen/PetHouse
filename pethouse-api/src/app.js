// ============================================================
// PETHOUSE API · Aplicación Express (ensambla los 7 módulos)
// ============================================================
import express from 'express'
import cors from 'cors'

import authRoutes from './routes/auth.js'
import hospedajesRoutes from './routes/hospedajes.js'
import reservasRoutes from './routes/reservas.js'
import actividadesRoutes from './routes/actividades.js'
import resenasRoutes from './routes/resenas.js'
import chatRoutes from './routes/chat.js'
import iaRoutes from './routes/ia.js'
import { manejadorErrores, noEncontrado } from './middleware/middleware.js'

const app = express()

app.use(cors())
app.use(express.json({ limit: '1mb' }))

app.get('/health', (_req, res) => res.json({ ok: true, servicio: 'pethouse-api', hora: new Date().toISOString() }))

app.use('/api/auth', authRoutes)
app.use('/api/hospedajes', hospedajesRoutes)
app.use('/api/reservas', reservasRoutes)
app.use('/api/actividades', actividadesRoutes)
app.use('/api/hospedajes', resenasRoutes)   // POST /api/hospedajes/:id/resenas
app.use('/api/conversaciones', chatRoutes)
app.use('/api/ia', iaRoutes)

app.use(noEncontrado)
app.use(manejadorErrores)

export default app
