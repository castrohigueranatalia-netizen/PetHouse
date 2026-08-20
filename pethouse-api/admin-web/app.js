// Mismo origen que la API (este archivo lo sirve el propio servidor de PetHouse en
// /admin) — por eso las peticiones van directo a /api/... sin necesitar configurar CORS
// ni una URL base aparte, a diferencia de la app de iOS.
//
// Archivo APARTE (no <script> dentro de index.html) a propósito: el Content-Security-Policy
// que agrega helmet (ver src/app.js) bloquea JavaScript escrito directo dentro del HTML —
// solo permite scripts de archivos como este, cargados con <script src="...">.
const API = '/api'
const LLAVE_TOKEN = 'pethouse_admin_token'

const $ = (sel) => document.querySelector(sel)
const pantallaLogin = $('#pantallaLogin')
const pantallaDashboard = $('#pantallaDashboard')

function tokenGuardado() { return localStorage.getItem(LLAVE_TOKEN) }
function guardarToken(t) { localStorage.setItem(LLAVE_TOKEN, t) }
function borrarToken() { localStorage.removeItem(LLAVE_TOKEN) }

async function llamarApi(ruta, opciones = {}) {
  const resp = await fetch(API + ruta, {
    ...opciones,
    headers: {
      'Content-Type': 'application/json',
      ...(opciones.headers || {}),
      Authorization: 'Bearer ' + tokenGuardado()
    }
  })
  if (resp.status === 401) {
    // El access token dura 15 min y este panel no implementa refresh (uso ocasional,
    // sesiones cortas) — si vence, simplemente se pide iniciar sesión de nuevo.
    cerrarSesion('Tu sesión venció. Inicia sesión de nuevo.')
    throw new Error('sesión expirada')
  }
  const datos = await resp.json().catch(() => ({}))
  if (!resp.ok) throw new Error(datos.error || 'Error al conectar con el servidor.')
  return datos
}

function cerrarSesion(mensaje) {
  borrarToken()
  pantallaDashboard.classList.add('oculto')
  pantallaLogin.classList.remove('oculto')
  if (mensaje) mostrarErrorLogin(mensaje)
}

function mostrarErrorLogin(msg) {
  const el = $('#errorLogin')
  el.textContent = msg
  el.classList.remove('oculto')
}

$('#formLogin').addEventListener('submit', async (e) => {
  e.preventDefault()
  const email = $('#campoEmail').value.trim()
  const password = $('#campoPassword').value
  const btn = $('#btnLogin')
  $('#errorLogin').classList.add('oculto')
  btn.disabled = true
  btn.textContent = 'Entrando…'
  try {
    const resp = await fetch(API + '/auth/login', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ email, password })
    })
    const datos = await resp.json()
    if (!resp.ok) throw new Error(datos.error || 'No se pudo iniciar sesión.')
    if (datos.usuario.rol !== 'admin') {
      throw new Error('Esta cuenta no es de administrador.')
    }
    guardarToken(datos.accessToken)
    mostrarDashboard()
  } catch (err) {
    mostrarErrorLogin(err.message)
  } finally {
    btn.disabled = false
    btn.textContent = 'Entrar'
  }
})

$('#btnLogout').addEventListener('click', () => cerrarSesion())

const ETIQUETAS_ESTADO = {
  pendiente: 'Pendiente', confirmada: 'Confirmada', completada: 'Completada',
  cancelada: 'Cancelada', rechazada: 'Rechazada'
}

function tarjetaStat(valor, etiqueta) {
  const div = document.createElement('div')
  div.className = 'stat'
  div.innerHTML = `<div class="valor">${valor}</div><div class="etiqueta">${etiqueta}</div>`
  return div
}

async function cargarEstadisticas() {
  const e = await llamarApi('/admin/estadisticas')
  const grid = $('#gridStats')
  grid.innerHTML = ''
  grid.append(
    tarjetaStat(e.totalUsuarios, 'Usuarios registrados'),
    tarjetaStat(e.totalAnfitriones, 'Son anfitriones'),
    tarjetaStat(e.usuariosConReserva, 'Han hecho una reserva'),
    tarjetaStat(e.totalHospedajes, 'Hospedajes publicados'),
    tarjetaStat(e.totalReservas, 'Reservas en total'),
    tarjetaStat(e.reservasActivas, 'Reservas activas ahora'),
    tarjetaStat(e.solicitudesPendientes, 'Solicitudes por revisar')
  )

  const tablaEstados = $('#tablaEstados')
  if (!e.reservasPorEstado.length) {
    tablaEstados.innerHTML = '<tr><td class="vacio">Todavía no hay reservas.</td></tr>'
  } else {
    tablaEstados.innerHTML = '<tr><th>Estado</th><th>Cantidad</th></tr>' +
      e.reservasPorEstado.map(r =>
        `<tr><td><span class="pill ${r.estado}">${ETIQUETAS_ESTADO[r.estado] || r.estado}</span></td><td>${r.total}</td></tr>`
      ).join('')
  }

  const tablaCiudades = $('#tablaCiudades')
  if (!e.reservasPorCiudad.length) {
    tablaCiudades.innerHTML = '<tr><td class="vacio">Todavía no hay reservas.</td></tr>'
  } else {
    tablaCiudades.innerHTML = '<tr><th>Ciudad</th><th>Reservas</th></tr>' +
      e.reservasPorCiudad.map(c => `<tr><td>${c.ciudad}</td><td>${c.total}</td></tr>`).join('')
  }
}

async function cargarSolicitudes() {
  const { solicitudes } = await llamarApi('/admin/solicitudes?estado=pendiente')
  const contenedor = $('#listaSolicitudes')
  if (!solicitudes.length) {
    contenedor.innerHTML = '<div class="vacio">No hay solicitudes pendientes por revisar.</div>'
    return
  }
  contenedor.innerHTML = ''
  for (const s of solicitudes) {
    const fila = document.createElement('div')
    fila.className = 'solicitud'
    fila.innerHTML = `
      <div class="info">
        <b>${s.usuario_nombre}</b>
        <span>${s.usuario_email} · Cédula ${s.cedula}</span>
      </div>
      <div class="acciones">
        <button class="btnAprobar">Aprobar</button>
        <button class="btnRechazar">Rechazar</button>
      </div>`
    fila.querySelector('.btnAprobar').addEventListener('click', () => resolverSolicitud(s.id, 'aprobar'))
    fila.querySelector('.btnRechazar').addEventListener('click', () => resolverSolicitud(s.id, 'rechazar'))
    contenedor.append(fila)
  }
}

async function resolverSolicitud(id, accion) {
  if (!confirm(accion === 'aprobar' ? '¿Aprobar esta solicitud de anfitrión?' : '¿Rechazar esta solicitud?')) return
  try {
    await llamarApi(`/admin/solicitudes/${id}/${accion}`, { method: 'POST' })
    await Promise.all([cargarEstadisticas(), cargarSolicitudes()])
  } catch (err) {
    alert(err.message)
  }
}

async function mostrarDashboard() {
  pantallaLogin.classList.add('oculto')
  pantallaDashboard.classList.remove('oculto')
  $('#cargandoDatos').classList.remove('oculto')
  $('#contenido').classList.add('oculto')
  try {
    await Promise.all([cargarEstadisticas(), cargarSolicitudes()])
    $('#cargandoDatos').classList.add('oculto')
    $('#contenido').classList.remove('oculto')
  } catch (err) {
    if (err.message !== 'sesión expirada') alert(err.message)
  }
}

if (tokenGuardado()) mostrarDashboard()
