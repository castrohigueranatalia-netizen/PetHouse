// ============================================================
// PETHOUSE API · Denuncias (reportar anfitriones, usuarios y mensajes)
// POST /api/denuncias
//
// El lado de administración (listar, revisar/descartar, bloquear la cuenta denunciada) está
// en routes/admin.js — ver db/30-denuncias.sql para el porqué del nombre "denuncias" (no
// "reportes", que ya significa los informes de comisión en el panel).
// ============================================================
import { Router } from 'express'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

const TIPOS_VALIDOS = ['anfitrion', 'usuario', 'mensaje']
const MOTIVOS_VALIDOS = ['spam', 'acoso', 'contenido_inapropiado', 'informacion_falsa', 'fraude', 'otro']

r.post('/', auth, async (req, res, next) => {
  try {
    const { usuarioDenunciadoId, tipo, motivo, comentario, mensajeId, hospedajeId } = req.body || {}

    if (!usuarioDenunciadoId) return res.status(400).json({ error: 'Falta usuarioDenunciadoId.' })
    if (usuarioDenunciadoId === req.usuario.id) return res.status(400).json({ error: 'No puedes denunciarte a ti mismo.' })
    if (!TIPOS_VALIDOS.includes(tipo)) return res.status(400).json({ error: 'Tipo de denuncia inválido.' })
    if (!MOTIVOS_VALIDOS.includes(motivo)) return res.status(400).json({ error: 'Motivo inválido.' })

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
         (denunciante_id, usuario_denunciado_id, tipo, motivo, comentario, mensaje_id, mensaje_texto, hospedaje_id)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
       RETURNING id, creado_en`,
      [req.usuario.id, usuarioDenunciadoId, tipo, motivo, comentario || null, mensajeId || null, mensajeTexto, hospedajeId || null]
    )

    res.status(201).json({ ok: true, denuncia: rows[0] })
  } catch (err) { next(err) }
})

export default r
