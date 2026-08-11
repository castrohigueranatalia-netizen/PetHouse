// ============================================================
// PETHOUSE API · Verificación de seguridad + preferencias de anfitrión
// POST/GET /api/anfitrion/verificacion · POST/GET /api/anfitrion/preferencias
//
// Paso obligatorio antes de poder publicar hospedajes. Enviar la verificación deja el
// registro en estado 'pendiente' — YA NO activa usuarios.es_anfitrion de una vez: eso
// ahora requiere que un administrador la apruebe (ver routes/admin.js,
// POST /api/admin/verificaciones/:id/aprobar). Antes era self-serve porque no existía
// panel de revisión; ahora que existe, la aprobación real es la única forma de activarla.
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

function comoArreglo(valor) {
  if (Array.isArray(valor)) return valor.filter((v) => typeof v === 'string' && v.trim())
  return []
}

// ---- Verificación ----

r.get('/verificacion', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM verificaciones_anfitrion WHERE usuario_id = $1',
      [req.usuario.id]
    )
    res.json({ verificacion: rows[0] || null })
  } catch (err) { next(err) }
})

r.post('/verificacion', auth, async (req, res, next) => {
  try {
    const {
      nombreLegal, cedula, certificadoPolicialUrl,
      referencias, fotosPersona, fotosVivienda
    } = req.body || {}

    if (!nombreLegal || String(nombreLegal).trim().length < 3) {
      return res.status(400).json({ error: 'Ingresa tu nombre legal completo.' })
    }
    if (!cedula || String(cedula).trim().length < 5) {
      return res.status(400).json({ error: 'Ingresa un número de cédula válido.' })
    }
    if (!certificadoPolicialUrl) {
      return res.status(400).json({ error: 'Adjunta tu certificado de antecedentes policiales.' })
    }
    const fotosPersonaArr = comoArreglo(fotosPersona)
    const fotosViviendaArr = comoArreglo(fotosVivienda)
    if (!fotosPersonaArr.length) return res.status(400).json({ error: 'Adjunta al menos una foto tuya.' })
    if (!fotosViviendaArr.length) return res.status(400).json({ error: 'Adjunta al menos una foto del lugar donde vives.' })

    // Re-enviar una verificación (ej. tras un rechazo, corrigiendo datos) vuelve a dejarla
    // en 'pendiente' — nunca reactiva es_anfitrion por su cuenta, eso lo decide un admin.
    const { rows } = await pool.query(
      `INSERT INTO verificaciones_anfitrion
         (usuario_id, nombre_legal, cedula, certificado_policial_url, referencias, fotos_persona, fotos_vivienda, estado, actualizado_en)
       VALUES ($1, $2, $3, $4, $5, $6, $7, 'pendiente', now())
       ON CONFLICT (usuario_id) DO UPDATE SET
         nombre_legal = EXCLUDED.nombre_legal,
         cedula = EXCLUDED.cedula,
         certificado_policial_url = EXCLUDED.certificado_policial_url,
         referencias = EXCLUDED.referencias,
         fotos_persona = EXCLUDED.fotos_persona,
         fotos_vivienda = EXCLUDED.fotos_vivienda,
         estado = 'pendiente',
         actualizado_en = now()
       RETURNING *`,
      [req.usuario.id, String(nombreLegal).trim(), String(cedula).trim(), certificadoPolicialUrl,
       comoArreglo(referencias), fotosPersonaArr, fotosViviendaArr]
    )
    res.status(201).json({ verificacion: rows[0] })
  } catch (err) { next(err) }
})

// ---- Preferencias de cuidado ----

r.get('/preferencias', auth, async (req, res, next) => {
  try {
    const { rows } = await pool.query(
      'SELECT * FROM preferencias_anfitrion WHERE usuario_id = $1',
      [req.usuario.id]
    )
    res.json({ preferencias: rows[0] || null })
  } catch (err) { next(err) }
})

r.post('/preferencias', auth, async (req, res, next) => {
  try {
    const especies = comoArreglo(req.body?.especies)
    const modalidades = comoArreglo(req.body?.modalidades)
    const tamanos = comoArreglo(req.body?.tamanos)

    if (!especies.length) return res.status(400).json({ error: 'Elige al menos una especie que prefieras cuidar.' })
    if (!modalidades.length) return res.status(400).json({ error: 'Elige si prefieres cuidar por días, por horas, o ambos.' })
    if (!tamanos.length) return res.status(400).json({ error: 'Elige al menos un tamaño de mascota.' })

    const { rows } = await pool.query(
      `INSERT INTO preferencias_anfitrion (usuario_id, especies, modalidades, tamanos, actualizado_en)
       VALUES ($1, $2, $3, $4, now())
       ON CONFLICT (usuario_id) DO UPDATE SET
         especies = EXCLUDED.especies, modalidades = EXCLUDED.modalidades,
         tamanos = EXCLUDED.tamanos, actualizado_en = now()
       RETURNING *`,
      [req.usuario.id, especies, modalidades, tamanos]
    )
    res.status(201).json({ preferencias: rows[0] })
  } catch (err) {
    // Las columnas tienen CHECK (especies <@ ARRAY[...]) — un valor fuera de la lista
    // permitida cae aquí como 23514 (fuera de rango), ya manejado por el middleware global.
    next(err)
  }
})

export default r
