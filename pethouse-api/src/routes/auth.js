// ============================================================
// PETHOUSE API · Módulo Auth
// POST /api/auth/registro · /login · /refresh · /logout · /me
// ============================================================
import { Router } from 'express'
import bcrypt from 'bcryptjs'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'
import { emitirTokens, renovarRefresh, revocarRefresh } from '../lib/tokens.js'

const r = Router()

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

// ---- Registro (datos personales + correo + contraseña) ----
r.post('/registro', async (req, res, next) => {
  try {
    // `es_anfitrion` NO se puede activar desde el registro (ni con ningún atajo): la
    // única forma de activarla es completar la verificación de seguridad
    // (POST /api/anfitrion/verificacion — nombre legal, cédula, certificado de
    // antecedentes, fotos). `rol` se conserva solo como intención principal para mostrar
    // en UI. El cliente puede mandar `esAnfitrion` únicamente para decidir, del lado de
    // la app, si lleva al usuario derecho al formulario de verificación después de
    // registrarse — el servidor lo ignora para efectos de autorización.
    const { nombre, telefono, email, password, rol = 'cliente', mascotaNombre } = req.body || {}

    if (!nombre || String(nombre).trim().length < 3) return res.status(400).json({ error: 'Ingresa tu nombre completo.' })
    if (!email || !EMAIL_RE.test(String(email))) return res.status(400).json({ error: 'Correo electrónico inválido.' })
    if (!password || String(password).length < 6) return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres.' })
    if (!['cliente', 'anfitrion'].includes(rol)) return res.status(400).json({ error: 'Rol inválido.' })

    const hash = await bcrypt.hash(String(password), 10)
    const { rows } = await pool.query(
      `INSERT INTO usuarios (nombre, email, telefono, password_hash, rol)
       VALUES ($1, $2, $3, $4, $5)
       RETURNING id, nombre, email, rol, verificado, es_anfitrion, creado_en`,
      [String(nombre).trim(), String(email).trim().toLowerCase(), telefono || null, hash, rol]
    )
    const usuario = rows[0]

    if (mascotaNombre && String(mascotaNombre).trim()) {
      await pool.query(
        `INSERT INTO mascotas (usuario_id, nombre, especie) VALUES ($1, $2, 'perro')`,
        [usuario.id, String(mascotaNombre).trim()]
      )
    }

    const tokens = await emitirTokens(usuario, req.headers['user-agent'])
    res.status(201).json({ usuario, ...tokens })
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Ya existe una cuenta con este correo.' })
    next(err)
  }
})

// ---- Login (correo + contraseña) ----
r.post('/login', async (req, res, next) => {
  try {
    const { email, password } = req.body || {}
    if (!email || !password) return res.status(400).json({ error: 'Ingresa tu correo y contraseña.' })

    const { rows } = await pool.query('SELECT * FROM usuarios WHERE email = $1', [String(email).trim().toLowerCase()])
    if (!rows.length) return res.status(401).json({ error: 'No encontramos una cuenta con ese correo.' })

    const ok = await bcrypt.compare(String(password), rows[0].password_hash).catch(() => false)
    if (!ok) return res.status(401).json({ error: 'Contraseña incorrecta.' })

    const { password_hash, ...usuario } = rows[0]
    const tokens = await emitirTokens(usuario, req.headers['user-agent'])
    res.json({ usuario, ...tokens })
  } catch (err) { next(err) }
})

// ---- Renovar sesión con el refresh token ----
r.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body || {}
    if (!refreshToken) return res.status(400).json({ error: 'Falta el refresh token.' })
    const usuario = await renovarRefresh(refreshToken)
    if (!usuario) return res.status(401).json({ error: 'Sesión expirada. Inicia sesión de nuevo.' })
    const tokens = await emitirTokens(usuario, req.headers['user-agent'])
    res.json({ usuario, ...tokens })
  } catch (err) { next(err) }
})

// ---- Cerrar sesión (revoca el refresh) ----
r.post('/logout', async (req, res, next) => {
  try {
    const { refreshToken } = req.body || {}
    if (refreshToken) await revocarRefresh(refreshToken)
    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Datos del usuario logueado + sus mascotas ----
r.get('/me', auth, async (req, res, next) => {
  try {
    const { rows: mascotas } = await pool.query(
      'SELECT id, nombre, especie, raza, peso_kg, vacunas_dia FROM mascotas WHERE usuario_id = $1',
      [req.usuario.id]
    )
    res.json({ usuario: req.usuario, mascotas })
  } catch (err) { next(err) }
})

// ---- Editar perfil (nombre, teléfono, foto) ----
// Contrato ya consumido por PetHouseiOS/Networking/Services/PerfilService.swift.
r.patch('/me', auth, async (req, res, next) => {
  try {
    const { nombre, telefono, foto_url: fotoUrl } = req.body || {}

    if (nombre !== undefined && String(nombre).trim().length < 3) {
      return res.status(400).json({ error: 'Ingresa tu nombre completo.' })
    }

    const campos = []
    const valores = []
    if (nombre !== undefined) { valores.push(String(nombre).trim()); campos.push(`nombre = $${valores.length}`) }
    if (telefono !== undefined) { valores.push(telefono || null); campos.push(`telefono = $${valores.length}`) }
    if (fotoUrl !== undefined) { valores.push(fotoUrl || null); campos.push(`foto_url = $${valores.length}`) }

    if (!campos.length) return res.status(400).json({ error: 'No hay nada que actualizar.' })

    valores.push(req.usuario.id)
    const { rows } = await pool.query(
      `UPDATE usuarios SET ${campos.join(', ')} WHERE id = $${valores.length}
       RETURNING id, nombre, email, telefono, rol, verificado, foto_url, es_anfitrion, creado_en`,
      valores
    )
    res.json({ usuario: rows[0] })
  } catch (err) { next(err) }
})

export default r
