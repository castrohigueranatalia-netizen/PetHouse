// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Asistente
// POST /api/asistente
// ============================================================
import { Router } from 'express'
import { auth } from '../middleware/middleware.js'
import { preguntarAsistente } from '../services/asistente.js'

const r = Router()

r.post('/', auth, async (req, res, next) => {
  try {
    const { mensajes } = req.body || {}
    if (!Array.isArray(mensajes) || !mensajes.length) {
      return res.status(400).json({ error: 'Falta la pregunta.' })
    }
    if (mensajes.length > 40) {
      return res.status(400).json({ error: 'La conversación es muy larga; empieza una nueva.' })
    }
    if (mensajes[mensajes.length - 1]?.rol !== 'usuario') {
      return res.status(400).json({ error: 'El último mensaje debe ser del usuario.' })
    }

    const resultado = await preguntarAsistente(mensajes)
    if (resultado.error) return res.status(502).json({ error: resultado.error })
    res.json(resultado)
  } catch (err) { next(err) }
})

export default r
