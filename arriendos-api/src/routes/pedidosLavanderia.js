// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Pedidos de lavandería
// Cada pedido ("factura") tiene uno o más ítems (ropa, sábanas, lencería
// de cama, otros), cada uno con su cantidad y valor por unidad. El total
// del pedido (valor) y num_prendas se recalculan siempre a partir de los
// ítems, nunca se escriben sueltos.
// GET /api/pedidos-lavanderia · POST / · PUT /:id · DELETE /:id
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

const ESTADOS = ['en_proceso', 'entregado']
const TIPOS_PRENDA = ['ropa', 'sabanas', 'lenceria_cama', 'otros']

// ---- Listar pedidos (con sus ítems) ----
r.get('/', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(`
      SELECT pl.*, p.nombre AS personal_nombre,
             COALESCE((
               SELECT json_agg(json_build_object(
                 'id', i.id, 'tipo_prenda', i.tipo_prenda, 'cantidad', i.cantidad,
                 'valor_unitario', i.valor_unitario, 'subtotal', i.subtotal
               ) ORDER BY i.creado_en)
               FROM items_pedido_lavanderia i WHERE i.pedido_id = pl.id
             ), '[]') AS items
        FROM pedidos_lavanderia pl
        LEFT JOIN personal_limpieza p ON p.id = pl.personal_id
       ORDER BY pl.fecha_ingreso DESC, pl.creado_en DESC
    `)
    res.json({ pedidos: rows })
  } catch (err) { next(err) }
})

function validarCuerpo(body, { requerido }) {
  const { fecha_ingreso, estado } = body
  if (requerido && !fecha_ingreso) return 'Falta la fecha de ingreso.'
  if (estado && !ESTADOS.includes(estado)) return `Estado inválido (usa: ${ESTADOS.join(', ')}).`
  return null
}

function validarItems(items) {
  if (!Array.isArray(items) || !items.length) return 'El pedido necesita al menos una prenda/ítem.'
  for (const it of items) {
    if (!TIPOS_PRENDA.includes(it.tipo_prenda)) return `Tipo de prenda inválido (usa: ${TIPOS_PRENDA.join(', ')}).`
    if (!(Number(it.cantidad) > 0)) return 'Cada ítem necesita una cantidad mayor a 0.'
    if (!(Number(it.valor_unitario) >= 0)) return 'El valor por unidad no puede ser negativo.'
  }
  return null
}

// Reemplaza por completo los ítems de un pedido y recalcula sus totales.
async function reemplazarItems(client, pedidoId, items) {
  await client.query('DELETE FROM items_pedido_lavanderia WHERE pedido_id = $1', [pedidoId])
  for (const it of items) {
    await client.query(
      `INSERT INTO items_pedido_lavanderia (pedido_id, tipo_prenda, cantidad, valor_unitario) VALUES ($1,$2,$3,$4)`,
      [pedidoId, it.tipo_prenda, it.cantidad, it.valor_unitario]
    )
  }
  const totales = items.reduce((acc, it) => {
    acc.cantidad += Number(it.cantidad) || 0
    acc.valor += (Number(it.cantidad) || 0) * (Number(it.valor_unitario) || 0)
    return acc
  }, { cantidad: 0, valor: 0 })
  await client.query('UPDATE pedidos_lavanderia SET num_prendas = $1, valor = $2 WHERE id = $3', [totales.cantidad, totales.valor, pedidoId])
}

async function obtenerPedidoCompleto(id) {
  const { rows } = await pool.query(`
    SELECT pl.*, p.nombre AS personal_nombre,
           COALESCE((
             SELECT json_agg(json_build_object(
               'id', i.id, 'tipo_prenda', i.tipo_prenda, 'cantidad', i.cantidad,
               'valor_unitario', i.valor_unitario, 'subtotal', i.subtotal
             ) ORDER BY i.creado_en)
             FROM items_pedido_lavanderia i WHERE i.pedido_id = pl.id
           ), '[]') AS items
      FROM pedidos_lavanderia pl
      LEFT JOIN personal_limpieza p ON p.id = pl.personal_id
     WHERE pl.id = $1
  `, [id])
  return rows[0]
}

// ---- Crear pedido con sus ítems ----
r.post('/', auth, async (req, res, next) => {
  const body = req.body || {}
  const error = validarCuerpo(body, { requerido: true }) || validarItems(body.items)
  if (error) return res.status(400).json({ error })

  const client = await pool.connect()
  try {
    const { cliente_nombre, cliente_telefono, personal_id, fecha_ingreso, fecha_entrega, estado = 'en_proceso', notas, items } = body

    await client.query('BEGIN')
    const { rows } = await client.query(
      `INSERT INTO pedidos_lavanderia (cliente_nombre, cliente_telefono, personal_id, fecha_ingreso, fecha_entrega, estado, notas)
       VALUES ($1,$2,$3,$4,$5,$6,$7) RETURNING id`,
      [cliente_nombre || null, cliente_telefono || null, personal_id || null, fecha_ingreso, fecha_entrega || null, estado, notas || null]
    )
    await reemplazarItems(client, rows[0].id, items)
    await client.query('COMMIT')

    res.status(201).json({ pedido: await obtenerPedidoCompleto(rows[0].id) })
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {})
    next(err)
  } finally {
    client.release()
  }
})

// ---- Editar pedido (datos y/o ítems; si no mandas "items" no se tocan) ----
r.put('/:id', auth, async (req, res, next) => {
  const body = req.body || {}
  const error = validarCuerpo(body, { requerido: false }) || (body.items ? validarItems(body.items) : null)
  if (error) return res.status(400).json({ error })

  const client = await pool.connect()
  try {
    const campos = ['cliente_nombre', 'cliente_telefono', 'personal_id', 'fecha_ingreso', 'fecha_entrega', 'estado', 'notas']
    const sets = []
    const valores = []
    for (const campo of campos) {
      if (campo in body) {
        valores.push(body[campo] === '' ? null : body[campo])
        sets.push(`${campo} = $${valores.length}`)
      }
    }

    await client.query('BEGIN')

    const { rows: existe } = await client.query('SELECT 1 FROM pedidos_lavanderia WHERE id = $1', [req.params.id])
    if (!existe.length) {
      await client.query('ROLLBACK')
      return res.status(404).json({ error: 'Pedido no encontrado.' })
    }

    if (sets.length) {
      valores.push(req.params.id)
      await client.query(`UPDATE pedidos_lavanderia SET ${sets.join(', ')} WHERE id = $${valores.length}`, valores)
    }
    if (body.items) await reemplazarItems(client, req.params.id, body.items)

    await client.query('COMMIT')
    res.json({ pedido: await obtenerPedidoCompleto(req.params.id) })
  } catch (err) {
    await client.query('ROLLBACK').catch(() => {})
    next(err)
  } finally {
    client.release()
  }
})

// ---- Eliminar pedido (sus ítems se borran solos por la FK en cascada) ----
r.delete('/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query('DELETE FROM pedidos_lavanderia WHERE id = $1', [req.params.id])
    if (!rowCount) return res.status(404).json({ error: 'Pedido no encontrado.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
