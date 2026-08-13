// ============================================================
// PETHOUSE API · Módulo Mascotas (CRUD completo)
// POST /api/mascotas · PATCH /api/mascotas/:id · DELETE /api/mascotas/:id
//
// Antes de este módulo solo se podía crear UNA mascota, durante el registro
// (POST /api/auth/registro con mascotaNombre). Contrato consumido ya por
// PetHouseiOS/Networking/Services/MascotasService.swift.
//
// edad/tamano/necesita_medicamentos (db/13-ficha-mascota.sql): la ficha completa que ve el
// anfitrión al recibir una solicitud de reserva, para decidir si puede aceptar a esa
// mascota — ver MASCOTAS_DETALLE_SQL en lib/mascotasDetalleSql.js.
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

const ESPECIES_SUGERIDAS = ['perro', 'gato', 'otro']
const TAMANOS_SUGERIDOS = ['pequeno', 'mediano', 'grande']

function validarCampos({ nombre, especie, pesoKg, edad, tamano }, { nombreRequerido }) {
  if (nombreRequerido && (!nombre || String(nombre).trim().length < 1)) {
    return 'Ingresa el nombre de tu mascota.'
  }
  if (nombreRequerido && (!especie || String(especie).trim().length < 1)) {
    return 'Indica la especie de tu mascota.'
  }
  if (pesoKg !== undefined && pesoKg !== null && (Number.isNaN(Number(pesoKg)) || Number(pesoKg) <= 0)) {
    return 'El peso debe ser un número mayor que 0.'
  }
  if (edad !== undefined && edad !== null && (Number.isNaN(Number(edad)) || Number(edad) < 0 || Number(edad) > 40)) {
    return 'La edad debe ser un número entre 0 y 40.'
  }
  if (tamano !== undefined && tamano !== null && !TAMANOS_SUGERIDOS.includes(tamano)) {
    return 'El tamaño debe ser pequeno, mediano o grande.'
  }
  return null
}

r.post('/', auth, async (req, res, next) => {
  try {
    const {
      nombre, especie, raza, edad, tamano,
      peso_kg: pesoKg, vacunas_dia: vacunasDia,
      necesita_medicamentos: necesitaMedicamentos, notas
    } = req.body || {}
    const errorValidacion = validarCampos({ nombre, especie, pesoKg, edad, tamano }, { nombreRequerido: true })
    if (errorValidacion) return res.status(400).json({ error: errorValidacion })

    const { rows } = await pool.query(
      `INSERT INTO mascotas (usuario_id, nombre, especie, raza, edad, tamano, peso_kg, vacunas_dia, necesita_medicamentos, notas)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
       RETURNING id, nombre, especie, raza, edad, tamano, peso_kg, vacunas_dia, necesita_medicamentos, notas, usuario_id`,
      [req.usuario.id, String(nombre).trim(), String(especie).trim(), raza || null, edad ?? null,
       tamano || null, pesoKg ?? null, Boolean(vacunasDia), Boolean(necesitaMedicamentos), notas || null]
    )
    res.status(201).json({ mascota: rows[0] })
  } catch (err) { next(err) }
})

r.patch('/:id', auth, async (req, res, next) => {
  try {
    const {
      nombre, especie, raza, edad, tamano,
      peso_kg: pesoKg, vacunas_dia: vacunasDia,
      necesita_medicamentos: necesitaMedicamentos, notas
    } = req.body || {}
    const errorValidacion = validarCampos({ nombre, especie, pesoKg, edad, tamano }, { nombreRequerido: false })
    if (errorValidacion) return res.status(400).json({ error: errorValidacion })

    const campos = []
    const valores = []
    const set = (col, val) => { valores.push(val); campos.push(`${col} = $${valores.length}`) }
    if (nombre !== undefined) set('nombre', String(nombre).trim())
    if (especie !== undefined) set('especie', String(especie).trim())
    if (raza !== undefined) set('raza', raza || null)
    if (edad !== undefined) set('edad', edad)
    if (tamano !== undefined) set('tamano', tamano || null)
    if (pesoKg !== undefined) set('peso_kg', pesoKg)
    if (vacunasDia !== undefined) set('vacunas_dia', Boolean(vacunasDia))
    if (necesitaMedicamentos !== undefined) set('necesita_medicamentos', Boolean(necesitaMedicamentos))
    if (notas !== undefined) set('notas', notas || null)

    if (!campos.length) return res.status(400).json({ error: 'No hay nada que actualizar.' })

    valores.push(req.params.id, req.usuario.id)
    const { rows } = await pool.query(
      `UPDATE mascotas SET ${campos.join(', ')}
        WHERE id = $${valores.length - 1} AND usuario_id = $${valores.length}
        RETURNING id, nombre, especie, raza, edad, tamano, peso_kg, vacunas_dia, necesita_medicamentos, notas, usuario_id`,
      valores
    )
    if (!rows.length) return res.status(404).json({ error: 'Mascota no encontrada.' })
    res.json({ mascota: rows[0] })
  } catch (err) { next(err) }
})

r.delete('/:id', auth, async (req, res, next) => {
  try {
    const { rowCount } = await pool.query(
      'DELETE FROM mascotas WHERE id = $1 AND usuario_id = $2',
      [req.params.id, req.usuario.id]
    )
    if (!rowCount) return res.status(404).json({ error: 'Mascota no encontrada.' })
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export { ESPECIES_SUGERIDAS, TAMANOS_SUGERIDOS }
export default r
