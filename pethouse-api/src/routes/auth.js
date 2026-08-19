// ============================================================
// PETHOUSE API · Módulo Auth
// POST /api/auth/registro · /login · /refresh · /logout · /logout-todo · /me
// POST /api/auth/olvide-password · /restablecer-password
// ============================================================
import { Router } from 'express'
import bcrypt from 'bcryptjs'
import { randomInt, createHash } from 'node:crypto'
import { pool } from '../config.js'
import { auth } from '../middleware/middleware.js'
import { emitirTokens, renovarRefresh, revocarRefresh, revocarTodasLasSesiones } from '../lib/tokens.js'
import { limitadorAuth } from '../middleware/rateLimit.js'
import { enviarCorreo } from '../lib/correo.js'

const r = Router()

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/

function generarCodigo() {
  return String(randomInt(0, 1000000)).padStart(6, '0')
}
function hashCodigo(codigo) {
  return createHash('sha256').update(codigo).digest('hex')
}

// `limitadorAuth` va PUNTUAL en /registro y /login, no en todo este router (antes estaba en
// app.js como `app.use('/api/auth', limitadorAuth, authRoutes)`) — /refresh, /logout, /me y
// PATCH /me no son adivinables por fuerza bruta (requieren un token válido que ya se tiene),
// pero SÍ se llaman todo el tiempo en el uso normal de la app (cada arranque, cada refresco
// de perfil, cada cierre de sesión). Contarlos contra el mismo cupo de 20 cada 15 min que
// login/registro hacía que alguien probando la app un rato terminara viendo "Demasiados
// intentos" sin haber hecho nada parecido a fuerza bruta — reportado en la práctica.
//
// ---- Registro (datos personales + correo + contraseña) ----
r.post('/registro', limitadorAuth, async (req, res, next) => {
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
r.post('/login', limitadorAuth, async (req, res, next) => {
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
// Rotativo: el refresh token que se usa acá queda revocado de inmediato y se emite uno
// nuevo — así, si alguna vez un refresh token se filtra y alguien más lo usa, el dueño
// legítimo lo nota en su próximo refresh normal (el token que él tenía ya no sirve, porque
// quien lo robó ya lo "gastó" primero) en vez de que ambos sigan usándolo en paralelo
// hasta que venza solo, hasta 30 días después.
r.post('/refresh', async (req, res, next) => {
  try {
    const { refreshToken } = req.body || {}
    if (!refreshToken) return res.status(400).json({ error: 'Falta el refresh token.' })
    const usuario = await renovarRefresh(refreshToken)
    if (!usuario) return res.status(401).json({ error: 'Sesión expirada. Inicia sesión de nuevo.' })
    await revocarRefresh(refreshToken)
    const tokens = await emitirTokens(usuario, req.headers['user-agent'])
    res.json({ usuario, ...tokens })
  } catch (err) { next(err) }
})

// ---- Cerrar sesión en TODOS los dispositivos (ej. sospecha de robo del teléfono) ----
r.post('/logout-todo', auth, async (req, res, next) => {
  try {
    await revocarTodasLasSesiones(req.usuario.id)
    res.json({ ok: true })
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

// ---- "Olvidé mi contraseña" (paso 1): envía un código de 6 dígitos por correo ----
// Responde igual exista o no una cuenta con ese correo — a propósito, para no dejar que
// alguien use este endpoint para averiguar qué correos están registrados en PetHouse.
r.post('/olvide-password', limitadorAuth, async (req, res, next) => {
  try {
    const { email } = req.body || {}
    if (!email || !EMAIL_RE.test(String(email))) {
      return res.status(400).json({ error: 'Ingresa un correo válido.' })
    }
    const correo = String(email).trim().toLowerCase()
    const { rows } = await pool.query('SELECT id, nombre FROM usuarios WHERE email = $1', [correo])

    if (rows.length) {
      const codigo = generarCodigo()
      await pool.query(
        `INSERT INTO restablecimientos_password (usuario_id, codigo_hash, expira_en)
         VALUES ($1, $2, now() + interval '15 minutes')`,
        [rows[0].id, hashCodigo(codigo)]
      )
      // Sin await a propósito: un correo lento/fallido no debe demorar la respuesta
      // (mismo principio que enviarPush) — y de todos modos la respuesta es genérica.
      enviarCorreo({
        para: correo,
        asunto: 'Tu código para restablecer tu contraseña en PetHouse',
        texto: `Hola ${rows[0].nombre},\n\nTu código para restablecer tu contraseña en PetHouse es: ${codigo}\n\nVence en 15 minutos. Si no lo pediste tú, ignora este mensaje — tu cuenta sigue segura.`
      })
    }

    res.json({ ok: true, mensaje: 'Si el correo existe, te enviamos un código de 6 dígitos.' })
  } catch (err) { next(err) }
})

// ---- "Olvidé mi contraseña" (paso 2): confirma el código y guarda la contraseña nueva ----
r.post('/restablecer-password', limitadorAuth, async (req, res, next) => {
  try {
    const { email, codigo, passwordNueva } = req.body || {}
    if (!email || !codigo) return res.status(400).json({ error: 'Faltan datos.' })
    if (!passwordNueva || String(passwordNueva).length < 6) {
      return res.status(400).json({ error: 'La contraseña debe tener al menos 6 caracteres.' })
    }

    const correo = String(email).trim().toLowerCase()
    const { rows: usuarios } = await pool.query('SELECT id FROM usuarios WHERE email = $1', [correo])
    // Mismo mensaje genérico tanto si el correo no existe como si el código está mal —
    // no hay forma de distinguir "correo equivocado" de "código equivocado" desde afuera.
    if (!usuarios.length) return res.status(400).json({ error: 'Código incorrecto o vencido.' })

    const { rows } = await pool.query(
      `SELECT id FROM restablecimientos_password
        WHERE usuario_id = $1 AND codigo_hash = $2 AND NOT usado AND expira_en > now()
        ORDER BY creado_en DESC LIMIT 1`,
      [usuarios[0].id, hashCodigo(String(codigo).trim())]
    )
    if (!rows.length) return res.status(400).json({ error: 'Código incorrecto o vencido.' })

    const hash = await bcrypt.hash(String(passwordNueva), 10)
    await pool.query('UPDATE usuarios SET password_hash = $1 WHERE id = $2', [hash, usuarios[0].id])
    await pool.query('UPDATE restablecimientos_password SET usado = TRUE WHERE id = $1', [rows[0].id])
    // Cierra TODAS las sesiones existentes de esta cuenta — si alguien más tenía acceso
    // con la contraseña vieja (o un refresh token robado), queda fuera apenas se cambia.
    await revocarTodasLasSesiones(usuarios[0].id)

    res.json({ ok: true })
  } catch (err) { next(err) }
})

// ---- Datos del usuario logueado + sus mascotas ----
r.get('/me', auth, async (req, res, next) => {
  try {
    // Ficha completa (antes solo traía id/nombre/especie/raza/peso_kg/vacunas_dia — ni
    // siquiera `notas`): MascotaFormView necesita todo esto para poder editar una mascota
    // sin perderle datos que ya tenía guardados.
    const { rows: mascotas } = await pool.query(
      `SELECT id, nombre, especie, raza, edad, tamano, peso_kg, vacunas_dia,
              necesita_medicamentos, notas, fotos
         FROM mascotas WHERE usuario_id = $1`,
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
