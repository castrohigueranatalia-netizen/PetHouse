// ============================================================
// PETHOUSE API · Rate limiting (ver ARCHITECTURE_AUDIT.md §6, gap bloqueante #3)
// Protege /api/auth/* de fuerza bruta y /api/ia de abuso de la cuota de Gemini.
// ============================================================
import rateLimit from 'express-rate-limit'

const manejador = (req, res) => {
  res.status(429).json({ error: 'Demasiados intentos. Espera un momento y vuelve a intentarlo.' })
}

// Login/registro: 20 intentos cada 15 min por IP — generoso para uso normal (reintentos de
// contraseña, varios miembros de una casa en la misma red) pero corta fuerza bruta.
export const limitadorAuth = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 20,
  standardHeaders: true,
  legacyHeaders: false,
  handler: manejador
})

// IA: 30 consultas cada 15 min por IP — evita que una sola IP agote la cuota de Gemini.
export const limitadorIA = rateLimit({
  windowMs: 15 * 60 * 1000,
  limit: 30,
  standardHeaders: true,
  legacyHeaders: false,
  handler: manejador
})
