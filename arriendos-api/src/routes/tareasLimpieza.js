// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Tareas de limpieza
// GET /api/tareas-limpieza · POST / · PUT /:id · DELETE /:id
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

const ESTADOS = ['pendiente', 'lista']

// ---- Marca como "lista" las tareas pendientes cuya hora ya pasó ----
// Así no hay que confirmar a mano cada limpieza: si ya se cumplió la hora
// programada (en horario de Cartagena/Bogotá) se da por hecha sola. Si una
// no se hizo de verdad, se puede volver a "Pendiente" con el botón normal.
// Las tareas sin hora se dan por vencidas solo al terminar el día (no hay
// forma de saber a qué hora exacta pasó).
async function marcarVencidasComoListas() {
  await pool.query(`
    UPDATE tareas_limpieza
       SET estado = 'lista'
     WHERE estado = 'pendiente'
       AND (fecha + COALESCE(hora, TIME '23:59:59')) < (now() AT TIME ZONE 'America/Bogota')
  `)
}

// ---- Listar tareas (filtros: desde, hasta, estado, apartamento_id) ----
// Incluye "mismo_dia_entrada": true si ese apartamento tiene una reserva
// confirmada/pagada cuya entrada cae justo el día de la tarea (hay que
// hacer el aseo con prisa, el próximo huésped llega el mismo día).
r.get('/', auth, async (req, res, next) => {
  try {
    await marcarVencidasComoListas()
    const { desde, hasta, estado, apartamento_id } = req.query
    const condiciones = []
    const valores = []

    if (desde) { valores.push(desde); condiciones.push(`t.fecha >= $${valores.length}`) }
    if (hasta) { valores.push(hasta); condiciones.push(`t.fecha <= $${valores.length}`) }
    if (estado) { valores.push(estado); condiciones.push(`t.estado = $${valores.length}`) }
    if (apartamento_id) { valores.push(apartamento_id); condiciones.push(`t.apartamento_id = $${valores.length}`) }

    const where = condiciones.length ? `WHERE ${condiciones.join(' AND ')}` : ''
    const { rows } = await pool.query(
      `SELECT t.*, a.nombre AS apartamento_nombre,
              p.nombre AS personal_nombre, p.telefono AS personal_telefono,
              EXISTS (
                SELECT 1 FROM reservas res
                 WHERE res.apartamento_id = t.apartamento_id
                   AND res.checkin = t.fecha
                   AND res.estado IN ('confirmada', 'pagada')
              ) AS mismo_dia_entrada
         FROM tareas_limpieza t
         JOIN apartamentos a ON a.id = t.apartamento_id
         LEFT JOIN personal_limpieza p ON p.id = t.personal_id
        ${where}
        ORDER BY t.fecha, t.hora NULLS LAST`,
      valores
    )
    res.json({ tareas: rows })
  } catch (err) { next(err) }
})

function validarCuerpo(body, { requerido }) {
  const { apartamento_id, fecha, estado } = body
  if (requerido && !apartamento_id) return 'Falta el apartamento.'
  if (requerido && !fecha) return 'Falta la fecha.'
  if (estado && !ESTADOS.includes(estado)) return `Estado inválido (usa: ${ESTADOS.join(', ')}).`
  return null
}

// ---- Crear tarea de limpieza ----
r.post('/', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const error = validarCuerpo(body, { requerido: true })
    if (error) return res.status(400).json({ error })

    const { apartamento_id, personal_id, fecha, hora, estado = 'pendiente', notas } = body
    const { rows } = await pool.query(
      `INSERT INTO tareas_limpieza (apartamento_id, personal_id, fecha, hora, estado, notas)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [apartamento_id, personal_id || null, fecha, hora || null, estado, notas || null]
    )
    res.status(201).json({ tarea: rows[0] })
  } catch (err) { next(err) }
})

// ---- Editar tarea (reasignar responsable, cambiar estado, fecha, hora...) ----
r.put('/:id', auth, async (req, res, next) => {
  try {
    const body = req.body || {}
    const error = validarCuerpo(body, { requerido: false })
    if (error) return res.status(400).json({ error })

    const campos = ['apartamento_id', 'personal_id', 'fecha', 'hora', 'estado', 'notas']
    const sets = []
    const valores = []
    for (const campo of campos) {
      if (campo in body) {
        valores.push(body[campo] === '' ? null : body[campo])
        sets.push(`${campo} = $${valores.length}`)
      }
    }
    if (!sets.length) return res.status(400).json({ error: 'No enviaste ningún dato para actualizar.' })

    valores.push(req.params.id)
    const { rows } = await pool.query(
      `UPDATE tareas_limpieza SET ${sets.join(', ')} WHERE id = $${valores.length} RETURNING *`,
      valores
    )
    if (!rows.length) return res.status(404).json({ error: 'Tarea no encontrada.' })
    res.json({ tarea: rows[0] })
  } catch (err) { next(err) }
})

// ---- Eliminar tarea ----
r.delete('/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM tareas_limpieza WHERE id = $1', [req.params.id])
    if (!rowCount) return res.status(404).json({ error: 'Tarea no encontrada.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
