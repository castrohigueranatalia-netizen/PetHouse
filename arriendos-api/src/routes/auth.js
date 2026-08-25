// ============================================================
// ARRIENDOS CARTAGENA API · Módulo Auth
// POST /api/auth/login · GET /api/auth/me · POST /api/auth/cambiar-password
// ============================================================
import { Router } from 'express'
import bcrypt from 'bcryptjs'
import jwt from 'jsonwebtoken'
import { pool, JWT_SECRET } from '../config.js'
import { auth } from '../middleware/middleware.js'

const r = Router()

// ---- Login (correo + contraseña) ----
r.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {}
    if (!email || !password) return res.status(400).json({ error: 'Ingresa tu correo y contraseña.' })

    const { rows } = await pool.query('SELECT * FROM usuarios WHERE email = $1', [String(email).trim().toLowerCase()])
    if (!rows.length) return res.status(401).json({ error: 'No encontramos una cuenta con ese correo.' })

    const ok = await bcrypt.compare(String(password), rows[0].password_hash).catch(() => false)
    if (!ok) return res.status(401).json({ error: 'Contraseña incorrecta.' })

    const token = jwt.sign({ uid: rows[0].id }, JWT_SECRET, { expiresIn: '30d' })
    const { password_hash, ...usuario } = rows[0]
    res.json({ usuario, token })
  } catch (err) { next(err) }
})

// ---- Datos del usuario logueado ----
r.get('/me', auth, async (req, res) => {
  res.json({ usuario: req.usuario })
})

// ---- Cambiar contraseña (requiere la actual) ----
r.post('/cambiar-password', auth, async (req, res, next) => {
  try {
    const { actual, nueva } = req.body || {}
    if (!actual || !nueva) return res.status(400).json({ error: 'Ingresa la contraseña actual y la nueva.' })
    if (String(nueva).length < 6) return res.status(400).json({ error: 'La nueva contraseña debe tener al menos 6 caracteres.' })

    const { rows } = await pool.query('SELECT password_hash FROM usuarios WHERE id = $1', [req.usuario.id])
    const ok = await bcrypt.compare(String(actual), rows[0].password_hash).catch(() => false)
    if (!ok) return res.status(401).json({ error: 'La contraseña actual no es correcta.' })

    const hash = await bcrypt.hash(String(nueva), 10)
    await pool.query('UPDATE usuarios SET password_hash = $1 WHERE id = $2', [hash, req.usuario.id])
    res.json({ ok: true })
  } catch (err) { next(err) }
})

export default r
