// ============================================================
// PETHOUSE API · Denuncias (reportar anfitriones, usuarios, mensajes y reseñas)
// POST /api/denuncias
//
// El lado de administración (listar, revisar/descartar, bloquear la cuenta denunciada) está
// en routes/admin.js — ver db/30-denuncias.sql para el porqué del nombre "denuncias" (no
// "reportes", que ya significa los informes de comisión en el panel) y
// db/31-denuncias-resenas.sql para el tipo "resena".
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

const TIPOS_VALIDOS = ['anfitrion', 'usuario', 'mensaje', 'resena']
const MOTIVOS_VALIDOS = ['spam', 'acoso', 'contenido_inapropiado', 'informacion_falsa', 'fraude', 'otro']

r.post('/', auth, async (req, res, next) => {
  try {
    let { usuarioDenunciadoId, tipo, motivo, comentario, mensajeId, hospedajeId, resenaId } = req.body || {}

    if (!TIPOS_VALIDOS.includes(tipo)) return res.status(400).json({ error: 'Tipo de denuncia inválido.' })
    if (!MOTIVOS_VALIDOS.includes(motivo)) return res.status(400).json({ error: 'Motivo inválido.' })

    let resenaTitulo = null
    let resenaTexto = null
    let resenaRating = null

    // Una reseña no trae el id de quien la escribió al cliente (los listados de reseñas
    // solo exponen su nombre, no autor_id) — se resuelve acá mismo, junto con una copia
    // del contenido, en vez de agregar autor_id a cada listado de reseñas solo para esto.
    // Prueba primero contra `resenas` (huésped → hospedaje) y si no, contra
    // `resenas_usuario` (anfitrión → huésped) — ver db/31-denuncias-resenas.sql.
    if (tipo === 'resena') {
      if (!resenaId) return res.status(400).json({ error: 'Falta resenaId.' })
      const { rows: deHospedaje } = await pool.query(
        'SELECT autor_id, hospedaje_id, titulo, texto, rating FROM resenas WHERE id = $1',
        [resenaId]
      )
      if (deHospedaje.length) {
        usuarioDenunciadoId = deHospedaje[0].autor_id
        hospedajeId = deHospedaje[0].hospedaje_id
        resenaTitulo = deHospedaje[0].titulo
        resenaTexto = deHospedaje[0].texto
        resenaRating = deHospedaje[0].rating
      } else {
        const { rows: deUsuario } = await pool.query(
          'SELECT autor_id, titulo, texto, rating FROM resenas_usuario WHERE id = $1',
          [resenaId]
        )
        if (!deUsuario.length) return res.status(404).json({ error: 'Reseña no encontrada.' })
        usuarioDenunciadoId = deUsuario[0].autor_id
        resenaTitulo = deUsuario[0].titulo
        resenaTexto = deUsuario[0].texto
        resenaRating = deUsuario[0].rating
      }
    }

    if (!usuarioDenunciadoId) return res.status(400).json({ error: 'Falta usuarioDenunciadoId.' })
    if (usuarioDenunciadoId === req.usuario.id) return res.status(400).json({ error: 'No puedes denunciarte a ti mismo.' })

    const { rows: denunciado } = await pool.query('SELECT id FROM usuarios WHERE id = $1', [usuarioDenunciadoId])
    if (!denunciado.length) return res.status(404).json({ error: 'Ese usuario no existe.' })

    // Copia el texto del mensaje AHORA (ver comentario en 30-denuncias.sql) — si no
    // pertenece al que denuncia, no se guarda nada (evita que alguien mande cualquier
    // mensaje_id ajeno solo para "citar" texto que no le corresponde ver).
    let mensajeTexto = null
    if (mensajeId) {
      const { rows: mensaje } = await pool.query(
        `SELECT m.texto FROM mensajes m
           JOIN conversaciones c ON c.id = m.conversacion_id
          WHERE m.id = $1 AND (c.usuario_id = $2 OR c.anfitrion_id = $2)`,
        [mensajeId, req.usuario.id]
      )
      if (!mensaje.length) return res.status(404).json({ error: 'Mensaje no encontrado.' })
      mensajeTexto = mensaje[0].texto
    }

    const { rows } = await pool.query(
      `INSERT INTO denuncias
         (denunciante_id, usuario_denunciado_id, tipo, motivo, comentario, mensaje_id, mensaje_texto,
          hospedaje_id, resena_titulo, resena_texto, resena_rating)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11)
       RETURNING id, creado_en`,
      [
        req.usuario.id, usuarioDenunciadoId, tipo, motivo, comentario || null, mensajeId || null, mensajeTexto,
        hospedajeId || null, resenaTitulo, resenaTexto, resenaRating
      ]
    )

    res.status(201).json({ ok: true, denuncia: rows[0] })
  } catch (err) { next(err) }
})

export default r
