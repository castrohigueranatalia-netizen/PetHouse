// ============================================================
// ARRIENDOS CARTAGENA API · Módulo iCal
// GET /api/apartamentos/:id/calendario.ics · POST /:id/sincronizar
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'
import { generarICS } from '../services/icalExport.js'
import { sincronizarApartamentoPorId } from '../services/icalSync.js'

const r = Router()

// ---- Exportar calendario (pública: Booking/Airbnb no puede iniciar sesión,
// así que se protege con el token secreto de la URL en vez de un JWT) ----
r.get('/:id/calendario.ics', async (req, res, next) => {
  try {
    const { rows } = await pool.query('SELECT id, nombre, ical_token FROM apartamentos WHERE id = $1', [req.params.id])
    if (!rows.length) return res.status(404).send('Apartamento no encontrado.')
    const apartamento = rows[0]
    if (!req.query.token || req.query.token !== apartamento.ical_token) {
      return res.status(403).send('Token inválido.')
    }

    const { rows: reservas } = await pool.query(
      `SELECT id, checkin, checkout, fuente FROM reservas
        WHERE apartamento_id = $1 AND estado = 'confirmada' AND checkout >= CURRENT_DATE - INTERVAL '1 day'
        ORDER BY checkin`,
      [apartamento.id]
    )
    res.set('Content-Type', 'text/calendar; charset=utf-8')
    res.send(generarICS(apartamento, reservas))
  } catch (err) { next(err) }
})

// ---- Sincronizar un apartamento ahora mismo (botón "Sincronizar" en la app) ----
r.post('/:id/sincronizar', auth, async (req, res, next) => {
  try {
    const resultado = await sincronizarApartamentoPorId(req.params.id)
    res.json(resultado)
  } catch (err) { next(err) }
})

export default r
