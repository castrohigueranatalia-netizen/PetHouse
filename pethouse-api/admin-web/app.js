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

const ETIQUETAS_VERIFICACION = { pendiente: 'Pendiente', aprobado: 'Aprobado', rechazado: 'Rechazado' }
const PILL_VERIFICACION = { pendiente: 'pendiente', aprobado: 'confirmada', rechazado: 'rechazada' }

async function cargarSolicitudes() {
  const estado = $('#filtroEstadoSolicitudes').value
  const { solicitudes } = await llamarApi(`/admin/solicitudes${estado ? `?estado=${estado}` : ''}`)
  const contenedor = $('#listaSolicitudes')
  if (!solicitudes.length) {
    contenedor.innerHTML = '<div class="vacio">No hay solicitudes que coincidan.</div>'
    return
  }
  contenedor.innerHTML = ''
  for (const s of solicitudes) {
    const fila = document.createElement('div')
    fila.className = 'solicitud'
    // Los botones de aprobar/rechazar solo tienen sentido mientras sigue 'pendiente' — una
    // ya resuelta muestra su resultado, no se puede volver a resolver desde acá.
    fila.innerHTML = `
      <div class="info">
        <b>${esc(s.usuario_nombre)}</b>
        <span>${esc(s.usuario_email)} · Cédula ${esc(s.cedula)}</span>
      </div>
      <div class="acciones">
        ${s.estado === 'pendiente'
          ? `<button class="btnAprobar">Aprobar</button><button class="btnRechazar">Rechazar</button>`
          : `<span class="pill ${PILL_VERIFICACION[s.estado] || ''}">${ETIQUETAS_VERIFICACION[s.estado] || esc(s.estado)}</span>`
        }
      </div>`
    if (s.estado === 'pendiente') {
      fila.querySelector('.btnAprobar').addEventListener('click', () => resolverSolicitud(s.id, 'aprobar'))
      fila.querySelector('.btnRechazar').addEventListener('click', () => resolverSolicitud(s.id, 'rechazar'))
    }
    contenedor.append(fila)
  }
}

$('#filtroEstadoSolicitudes').addEventListener('change', cargarSolicitudes)

// ---- Utilidad: texto de usuario/base de datos SIEMPRE escapado antes de meterlo en
// innerHTML — un nombre o correo con caracteres como "<" no debe interpretarse como HTML.
function esc(valor) {
  const div = document.createElement('div')
  div.textContent = valor ?? ''
  return div.innerHTML
}

const FORMATO_MONEDA = new Intl.NumberFormat('es-CO', { style: 'currency', currency: 'COP', maximumFractionDigits: 0 })
const FORMATO_FECHA = new Intl.DateTimeFormat('es-CO', { day: 'numeric', month: 'short', year: 'numeric' })
function formatoFecha(iso) { return iso ? FORMATO_FECHA.format(new Date(iso)) : '—' }

// ---- Navegación entre secciones ----

// El resumen solo necesita el CONTEO de solicitudes pendientes (ya viene incluido en
// /admin/estadisticas) — la lista completa con botones de aprobar/rechazar es de la
// pestaña Verificación, no se carga acá.
const CARGADORES_VISTA = {
  resumen: () => cargarEstadisticas(),
  usuarios: () => cargarUsuarios(),
  hospedajes: () => cargarHospedajes(),
  reservas: () => cargarReservas(),
  cancelaciones: () => cargarCancelaciones(),
  verificacion: () => cargarSolicitudes(),
  soporte: () => cargarSoporte(),
  legal: () => cargarLegal()
}

async function mostrarVista(nombre) {
  document.querySelectorAll('.navItem').forEach(b => b.classList.toggle('activo', b.dataset.vista === nombre))
  document.querySelectorAll('.vista').forEach(v => v.classList.toggle('oculto', v.id !== `vista${capitalizar(nombre)}`))
  try {
    await CARGADORES_VISTA[nombre]()
  } catch (err) {
    if (err.message !== 'sesión expirada') alert(err.message)
  }
}
function capitalizar(s) { return s.charAt(0).toUpperCase() + s.slice(1) }

document.querySelectorAll('.navItem').forEach(btn => {
  btn.addEventListener('click', () => mostrarVista(btn.dataset.vista))
})

// ---- Usuarios ----

let filtroUsuarios = ''
let temporizadorBusqueda = null

async function cargarUsuarios() {
  const { usuarios } = await llamarApi(`/admin/usuarios?porPagina=100&q=${encodeURIComponent(filtroUsuarios)}`)
  const tabla = $('#tablaUsuarios')
  if (!usuarios.length) {
    tabla.innerHTML = '<tr><td class="vacio">No hay usuarios que coincidan.</td></tr>'
    return
  }
  tabla.innerHTML = '<tr><th>Nombre</th><th>Correo</th><th>Rol</th><th>Mascotas</th><th>Reservas</th><th>Hospedajes</th></tr>' +
    usuarios.map(u => `
      <tr class="filaClicable" data-id="${u.id}">
        <td>${esc(u.nombre)}</td>
        <td>${esc(u.email)}</td>
        <td>${u.es_anfitrion ? 'Anfitrión' : 'Cliente'}</td>
        <td>${u.num_mascotas}</td>
        <td>${u.num_reservas}</td>
        <td>${u.num_hospedajes}</td>
      </tr>`
    ).join('')
  tabla.querySelectorAll('tr.filaClicable').forEach(fila => {
    fila.addEventListener('click', () => mostrarDetalleUsuario(fila.dataset.id))
  })
}

$('#buscarUsuarios').addEventListener('input', (e) => {
  filtroUsuarios = e.target.value
  clearTimeout(temporizadorBusqueda)
  temporizadorBusqueda = setTimeout(cargarUsuarios, 350)
})

async function mostrarDetalleUsuario(id) {
  const modal = $('#modalUsuario')
  const contenido = $('#modalContenido')
  contenido.innerHTML = '<div class="cargando">Cargando…</div>'
  modal.classList.remove('oculto')
  try {
    const d = await llamarApi(`/admin/usuarios/${id}`)
    const u = d.usuario
    let html = `
      <div class="fichaTitulo">${esc(u.nombre)}</div>
      <div class="fichaSub">${esc(u.email)} · ${u.es_anfitrion ? 'Anfitrión' : 'Cliente'} · desde ${formatoFecha(u.creado_en)}</div>
      <div class="fichaSeccion">
        <h3>Datos</h3>
        <div class="fichaFila"><span>Teléfono</span><span>${esc(u.telefono) || '—'}</span></div>
        <div class="fichaFila"><span>Rol</span><span>${esc(u.rol)}</span></div>
      </div>`

    if (d.mascotas.length) {
      html += `<div class="fichaSeccion"><h3>Mascotas (${d.mascotas.length})</h3>` +
        d.mascotas.map(m => `<div class="fichaFila"><span>${esc(m.nombre)}</span><span>${esc(m.especie)}${m.raza ? ' · ' + esc(m.raza) : ''}</span></div>`).join('') +
        `</div>`
    }
    if (d.hospedajes.length) {
      html += `<div class="fichaSeccion"><h3>Hospedajes (${d.hospedajes.length})</h3>` +
        d.hospedajes.map(h => `<div class="fichaFila"><span>${esc(h.titulo)}</span><span>${esc(h.localidad) || esc(h.ciudad)}</span></div>`).join('') +
        `</div>`
    }
    if (d.verificacion) {
      html += `<div class="fichaSeccion"><h3>Verificación de anfitrión</h3>` +
        `<div class="fichaFila"><span>Estado</span><span class="pill ${d.verificacion.estado === 'aprobado' ? 'confirmada' : d.verificacion.estado === 'rechazado' ? 'rechazada' : 'pendiente'}">${esc(d.verificacion.estado)}</span></div>` +
        `</div>`
    }
    if (d.reservas.length) {
      html += `<div class="fichaSeccion"><h3>Últimas reservas (${d.reservas.length})</h3>` +
        d.reservas.map(r => `<div class="fichaFila"><span>${esc(r.hospedaje_titulo)}</span><span>${FORMATO_MONEDA.format(r.total)} · ${esc(r.estado)}</span></div>`).join('') +
        `</div>`
    }
    contenido.innerHTML = html
  } catch (err) {
    contenido.innerHTML = `<div class="errorLogin">${esc(err.message)}</div>`
  }
}

$('#btnCerrarModal').addEventListener('click', () => $('#modalUsuario').classList.add('oculto'))
$('#modalUsuario').addEventListener('click', (e) => { if (e.target.id === 'modalUsuario') e.currentTarget.classList.add('oculto') })

// ---- Hospedajes ----

async function cargarHospedajes() {
  const { hospedajes } = await llamarApi('/admin/hospedajes?porPagina=100')
  const tabla = $('#tablaHospedajes')
  if (!hospedajes.length) {
    tabla.innerHTML = '<tr><td class="vacio">Todavía no hay hospedajes publicados.</td></tr>'
    return
  }
  tabla.innerHTML = '<tr><th>Hospedaje</th><th>Anfitrión</th><th>Ubicación</th><th>Precio/noche</th><th>Reservas</th><th>Estado</th></tr>' +
    hospedajes.map(h => `
      <tr>
        <td>${esc(h.titulo)}</td>
        <td>${esc(h.anfitrion_nombre)}</td>
        <td>${esc(h.localidad) || esc(h.barrio) || esc(h.ciudad)}</td>
        <td>${FORMATO_MONEDA.format(h.precio_noche)}</td>
        <td>${h.num_reservas}</td>
        <td><span class="pill ${h.activo ? 'confirmada' : 'cancelada'}">${h.activo ? 'Activo' : 'Inactivo'}</span></td>
      </tr>`
    ).join('')
}

// ---- Reservas ----

// Compartida entre la tabla de Reservas y la de Cancelaciones — misma forma de fila,
// solo cambia el filtro con el que se pidieron.
function filaReserva(r) {
  return `
    <tr>
      <td>${esc(r.codigo)}</td>
      <td>${esc(r.usuario_nombre)}</td>
      <td>${esc(r.hospedaje_titulo)}</td>
      <td>${esc(r.anfitrion_nombre)}</td>
      <td>${formatoFecha(r.desde)} → ${formatoFecha(r.hasta)}</td>
      <td>${FORMATO_MONEDA.format(r.total)}</td>
      <td><span class="pill ${ETIQUETAS_ESTADO[r.estado] ? r.estado : ''}">${ETIQUETAS_ESTADO[r.estado] || r.estado}</span></td>
    </tr>`
}
const ENCABEZADO_RESERVAS = '<tr><th>Código</th><th>Huésped</th><th>Hospedaje</th><th>Anfitrión</th><th>Fechas</th><th>Valor</th><th>Estado</th></tr>'

async function cargarReservas() {
  const estado = $('#filtroEstadoReservas').value
  const { reservas } = await llamarApi(`/admin/reservas?porPagina=100${estado ? `&estado=${estado}` : ''}`)
  const tabla = $('#tablaReservas')
  tabla.innerHTML = reservas.length
    ? ENCABEZADO_RESERVAS + reservas.map(filaReserva).join('')
    : '<tr><td class="vacio">No hay reservas que coincidan.</td></tr>'
}

$('#filtroEstadoReservas').addEventListener('change', cargarReservas)

// ---- Cancelaciones (reservas canceladas o rechazadas) ----

async function cargarCancelaciones() {
  const { reservas } = await llamarApi('/admin/reservas?porPagina=100&estado=canceladas')
  const tabla = $('#tablaCancelaciones')
  tabla.innerHTML = reservas.length
    ? ENCABEZADO_RESERVAS + reservas.map(filaReserva).join('')
    : '<tr><td class="vacio">No hay cancelaciones ni rechazos todavía.</td></tr>'
}

// ---- Soporte ----

const ETIQUETAS_SOPORTE = { abierto: 'Abierto', resuelto: 'Resuelto' }
const PILL_SOPORTE = { abierto: 'pendiente', resuelto: 'confirmada' }

async function cargarSoporte() {
  const estado = $('#filtroEstadoSoporte').value
  const { tickets } = await llamarApi(`/admin/soporte${estado ? `?estado=${estado}` : ''}`)
  const tabla = $('#tablaSoporte')
  if (!tickets.length) {
    tabla.innerHTML = '<tr><td class="vacio">No hay tickets que coincidan.</td></tr>'
    return
  }
  tabla.innerHTML = '<tr><th>Asunto</th><th>De</th><th>Mensajes</th><th>Última actividad</th><th>Estado</th></tr>' +
    tickets.map(t => `
      <tr class="filaClicable" data-id="${t.id}">
        <td>${esc(t.asunto)}</td>
        <td>${esc(t.usuario_nombre)}</td>
        <td>${t.num_mensajes}</td>
        <td>${formatoFecha(t.actualizado_en)}</td>
        <td><span class="pill ${PILL_SOPORTE[t.estado] || ''}">${ETIQUETAS_SOPORTE[t.estado] || esc(t.estado)}</span></td>
      </tr>`
    ).join('')
  tabla.querySelectorAll('tr.filaClicable').forEach(fila => {
    fila.addEventListener('click', () => mostrarDetalleTicket(fila.dataset.id))
  })
}

$('#filtroEstadoSoporte').addEventListener('change', cargarSoporte)

async function mostrarDetalleTicket(id) {
  const modal = $('#modalUsuario')
  const contenido = $('#modalContenido')
  contenido.innerHTML = '<div class="cargando">Cargando…</div>'
  modal.classList.remove('oculto')
  try {
    const { ticket, mensajes } = await llamarApi(`/admin/soporte/${id}`)
    contenido.innerHTML = `
      <div class="fichaTitulo">${esc(ticket.asunto)}</div>
      <div class="fichaSub">${esc(ticket.usuario_nombre)} · ${esc(ticket.usuario_email)} ·
        <span class="pill ${PILL_SOPORTE[ticket.estado] || ''}">${ETIQUETAS_SOPORTE[ticket.estado] || esc(ticket.estado)}</span>
      </div>
      <div class="hilo" id="hiloTicket">
        ${mensajes.map(m => `
          <div class="burbuja ${m.es_admin ? 'admin' : 'usuario'}">
            <span class="quien">${m.es_admin ? 'Tú (soporte)' : esc(ticket.usuario_nombre)}</span>
            ${esc(m.texto)}
          </div>`
        ).join('')}
      </div>
      <div class="cajaResponder">
        <textarea id="textoRespuesta" placeholder="Escribe una respuesta…"></textarea>
      </div>
      <div style="display:flex; gap:8px; margin-top:10px;">
        <button class="btnPrimario" id="btnResponderTicket" style="width:auto; padding:9px 18px;">Responder</button>
        ${ticket.estado === 'abierto' ? `<button class="btnSecundario" id="btnResolverTicket">Marcar resuelto</button>` : ''}
      </div>`

    $('#btnResponderTicket').addEventListener('click', () => responderTicket(id))
    const btnResolver = $('#btnResolverTicket')
    if (btnResolver) btnResolver.addEventListener('click', () => resolverTicket(id))
  } catch (err) {
    contenido.innerHTML = `<div class="errorLogin">${esc(err.message)}</div>`
  }
}

async function responderTicket(id) {
  const texto = $('#textoRespuesta').value.trim()
  if (!texto) return
  try {
    await llamarApi(`/admin/soporte/${id}/responder`, { method: 'POST', body: JSON.stringify({ texto }) })
    await mostrarDetalleTicket(id)
    await cargarSoporte()
  } catch (err) { alert(err.message) }
}

async function resolverTicket(id) {
  try {
    await llamarApi(`/admin/soporte/${id}/resolver`, { method: 'POST' })
    $('#modalUsuario').classList.add('oculto')
    await cargarSoporte()
  } catch (err) { alert(err.message) }
}

// ---- Entidad legal + documentos legales ----

async function cargarLegal() {
  const { entidad, documentos } = await llamarApi('/admin/legal')
  $('#legalNombre').value = entidad.nombre_legal || ''
  $('#legalNit').value = entidad.nit || ''
  $('#legalDomicilio').value = entidad.domicilio || ''
  $('#legalCorreo').value = entidad.correo_contacto || ''
  $('#legalTelefono').value = entidad.telefono_contacto || ''

  const privacidad = documentos.find(d => d.tipo === 'privacidad')
  const terminos = documentos.find(d => d.tipo === 'terminos')
  $('#textoPrivacidad').value = privacidad?.contenido || ''
  $('#textoTerminos').value = terminos?.contenido || ''
}

function mostrarGuardado(idIndicador) {
  const el = $(idIndicador)
  el.classList.remove('oculto')
  setTimeout(() => el.classList.add('oculto'), 2500)
}

$('#formEntidad').addEventListener('submit', async (e) => {
  e.preventDefault()
  try {
    await llamarApi('/admin/legal/entidad', {
      method: 'PUT',
      body: JSON.stringify({
        nombreLegal: $('#legalNombre').value.trim(),
        nit: $('#legalNit').value.trim(),
        domicilio: $('#legalDomicilio').value.trim(),
        correoContacto: $('#legalCorreo').value.trim(),
        telefonoContacto: $('#legalTelefono').value.trim()
      })
    })
    mostrarGuardado('#okEntidad')
  } catch (err) { alert(err.message) }
})

$('#formPrivacidad').addEventListener('submit', async (e) => {
  e.preventDefault()
  try {
    await llamarApi('/admin/legal/privacidad', { method: 'PUT', body: JSON.stringify({ contenido: $('#textoPrivacidad').value }) })
    mostrarGuardado('#okPrivacidad')
  } catch (err) { alert(err.message) }
})

$('#formTerminos').addEventListener('submit', async (e) => {
  e.preventDefault()
  try {
    await llamarApi('/admin/legal/terminos', { method: 'PUT', body: JSON.stringify({ contenido: $('#textoTerminos').value }) })
    mostrarGuardado('#okTerminos')
  } catch (err) { alert(err.message) }
})

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
    await mostrarVista('resumen')
    $('#cargandoDatos').classList.add('oculto')
    $('#contenido').classList.remove('oculto')
  } catch (err) {
    if (err.message !== 'sesión expirada') alert(err.message)
  }
}

if (tokenGuardado()) mostrarDashboard()
