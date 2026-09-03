// ============================================================
// PETHOUSE API · Módulo Legal (público, solo lectura)
// GET /api/legal/entidad · GET /api/legal/:tipo (privacidad|terminos)
//
// Sin `auth` a propósito: la app necesita poder mostrarle la política de privacidad y los
// términos de uso a alguien que TODAVÍA no tiene cuenta (ej. antes de registrarse) — un
// endpoint que exigiera sesión no serviría para eso. El contenido lo edita un admin desde
// el panel (ver POST/PUT en routes/admin.js); acá solo se lee.
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'

const r = Router()

const TIPOS_VALIDOS = ['privacidad', 'terminos']

r.get('/entidad', async (_req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT nombre_legal, nit, domicilio, correo_contacto, telefono_contacto FROM entidad_legal WHERE id = 1'
    )
    res.json({ entidad: rows[0] || null })
  } catch (err) { next(err) }
})

r.get('/:tipo', async (req, res, next) => {
  try {
    if (!TIPOS_VALIDOS.includes(req.params.tipo)) {
      return res.status(404).json({ error: 'Documento no encontrado.' })
    }
    const { rows } = await pool.query(
      'SELECT tipo, contenido, actualizado_en FROM documentos_legales WHERE tipo = $1',
      [req.params.tipo]
    )
    if (!rows.length) return res.status(404).json({ error: 'Documento no encontrado.' })
    res.json({ documento: rows[0] })
  } catch (err) { next(err) }
})

export default r
