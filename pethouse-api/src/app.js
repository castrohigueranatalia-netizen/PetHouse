// ============================================================
// PETHOUSE API · Aplicación Express (ensambla los módulos)
// ============================================================
import express from 'express'
import cors from 'cors'
import helmet from 'helmet'
import path from 'node:path'
import { fileURLToPath } from 'node:url'

import authRoutes from './routes/auth.js'
import hospedajesRoutes from './routes/hospedajes.js'
import reservasRoutes from './routes/reservas.js'
import actividadesRoutes from './routes/actividades.js'
import resenasRoutes from './routes/resenas.js'
import chatRoutes from './routes/chat.js'
import iaRoutes from './routes/ia.js'
import mascotasRoutes from './routes/mascotas.js'
import favoritosRoutes from './routes/favoritos.js'
import subidasRoutes, { uploadsDir, verificacionPrivadaRouter } from './routes/subidas.js'
import anfitrionVerificacionRoutes from './routes/anfitrion.js'
import adminRoutes from './routes/admin.js'
import usuariosRoutes from './routes/usuarios.js'
import notificacionesRoutes from './routes/notificaciones.js'
import { manejadorErrores, noEncontrado } from './middleware/middleware.js'
import { limitadorIA } from './middleware/rateLimit.js'
import { ALLOWED_ORIGINS } from './config.js'

const app = express()
const __dirname = path.dirname(fileURLToPath(import.meta.url))

// Headers de seguridad HTTP (auditoría §5): antes no había ninguno configurado, ni
// siquiera los básicos. `helmet()` agrega de una vez los que un escáner de seguridad
// espera encontrar — Strict-Transport-Security, X-Content-Type-Options,
// X-Frame-Options/frame-ancestors, Content-Security-Policy por defecto, entre otros.
// `crossOriginResourcePolicy: 'cross-origin'` es la única parte que hay que pisar: el
// valor por defecto de helmet ('same-origin') bloquearía que /uploads, /privado/
// verificacion y /semilla sirvan sus imágenes si alguna vez se cargan desde un origen
// distinto (ej. un futuro panel de admin web) — la app iOS nativa no se ve afectada de
// ninguna forma por esto, pero un consumidor basado en navegador sí lo notaría.
app.use(helmet({ crossOriginResourcePolicy: { policy: 'cross-origin' } }))

// Sin ALLOWED_ORIGINS configurado, `cors()` sigue abierto (ver config.js) — necesario para
// no romper apps nativas (no envían Origin) ni el desarrollo local.
app.use(cors(ALLOWED_ORIGINS ? { origin: ALLOWED_ORIGINS } : undefined))
app.use(express.json({ limit: '1mb' }))
// Archivos subidos vía POST /api/subidas (ver routes/subidas.js) — servidos como estáticos.
app.use('/uploads', express.static(uploadsDir))
// Fotos de verificación de anfitrión (cédula, antecedentes, persona, vivienda) — NUNCA
// públicas: viven fuera de `uploadsDir` y solo se sirven con una URL firmada de corta
// duración (ver lib/urlsPrivadas.js y routes/subidas.js).
app.use('/privado/verificacion', verificacionPrivadaRouter)
// Fotos reales de ejemplo (db/02-seed.sql las referencia como rutas relativas
// "/semilla/g1.jpg" etc. — antes eran nombres sin sentido como "guarderia-1", que no
// resolvían a ninguna imagen real desde un cliente nativo). Copiadas de ../_src/ (las
// mismas fotos de marca que usa index.html) a public/semilla con extensión real.
app.use('/semilla', express.static(path.join(__dirname, '..', 'public', 'semilla')))

// Panel de administración — página web aparte de la app de iOS (ver admin-web/index.html),
// servida por este mismo servidor. Al vivir en el mismo origen que la API, sus peticiones
// a /api/... son same-origin: no necesita configurar CORS aparte, y sigue funcionando
// igual sin importar dónde termine desplegándose la API (localhost hoy, un dominio real
// después). La autorización real la sigue haciendo el servidor (auth + soloAdmin en
// routes/admin.js) — esta página es solo la interfaz, no un mecanismo de seguridad.
app.use('/admin', express.static(path.join(__dirname, '..', 'admin-web')))

app.get('/health', (_req, res) => res.json({ ok: true, servicio: 'pethouse-api', hora: new Date().toISOString() }))

// El rate limit va DENTRO de auth.js, solo en /registro y /login (los únicos endpoints
// adivinables por fuerza bruta) — ver el comentario largo ahí sobre por qué NO va acá a
// nivel de router completo.
app.use('/api/auth', authRoutes)
app.use('/api/hospedajes', hospedajesRoutes)
app.use('/api/reservas', reservasRoutes)
app.use('/api/actividades', actividadesRoutes)
app.use('/api/hospedajes', resenasRoutes)   // POST /api/hospedajes/:id/resenas
app.use('/api/conversaciones', chatRoutes)
app.use('/api/ia', limitadorIA, iaRoutes)
app.use('/api/mascotas', mascotasRoutes)
app.use('/api/favoritos', favoritosRoutes)
app.use('/api/subidas', subidasRoutes)
app.use('/api/anfitrion', anfitrionVerificacionRoutes)
app.use('/api/admin', adminRoutes)
app.use('/api/usuarios', usuariosRoutes)
app.use('/api/notificaciones', notificacionesRoutes)

app.use(noEncontrado)
app.use(manejadorErrores)

export default app
