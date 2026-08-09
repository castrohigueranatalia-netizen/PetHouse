// ============================================================
// PETHOUSE API · Aplicación Express (ensambla los módulos)
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
import mascotasRoutes from './routes/mascotas.js'
import favoritosRoutes from './routes/favoritos.js'
import subidasRoutes, { uploadsDir } from './routes/subidas.js'
import { manejadorErrores, noEncontrado } from './middleware/middleware.js'
import { limitadorAuth, limitadorIA } from './middleware/rateLimit.js'
import { ALLOWED_ORIGINS } from './config.js'

const app = express()

// Sin ALLOWED_ORIGINS configurado, `cors()` sigue abierto (ver config.js) — necesario para
// no romper apps nativas (no envían Origin) ni el desarrollo local.
app.use(cors(ALLOWED_ORIGINS ? { origin: ALLOWED_ORIGINS } : undefined))
app.use(express.json({ limit: '1mb' }))
// Archivos subidos vía POST /api/subidas (ver routes/subidas.js) — servidos como estáticos.
app.use('/uploads', express.static(uploadsDir))

app.get('/health', (_req, res) => res.json({ ok: true, servicio: 'pethouse-api', hora: new Date().toISOString() }))

app.use('/api/auth', limitadorAuth, authRoutes)
app.use('/api/hospedajes', hospedajesRoutes)
app.use('/api/reservas', reservasRoutes)
app.use('/api/actividades', actividadesRoutes)
app.use('/api/hospedajes', resenasRoutes)   // POST /api/hospedajes/:id/resenas
app.use('/api/conversaciones', chatRoutes)
app.use('/api/ia', limitadorIA, iaRoutes)
app.use('/api/mascotas', mascotasRoutes)
app.use('/api/favoritos', favoritosRoutes)
app.use('/api/subidas', subidasRoutes)

app.use(noEncontrado)
app.use(manejadorErrores)

export default app
