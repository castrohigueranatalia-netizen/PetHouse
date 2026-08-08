// Smoke test del index.html autocontenido (HTML+CSS+JS vanilla)
import { JSDOM } from 'jsdom'
import { readFileSync } from 'fs'

const html = readFileSync(new URL('./index.html', import.meta.url), 'utf-8')
const dom = new JSDOM(html, { url: 'http://localhost/', runScripts: 'dangerously', pretendToBeVisual: true })
const { window } = dom
const { document } = window

window.scrollTo = () => {}
const wait = (ms) => new Promise((r) => setTimeout(r, ms))

const results = []
const check = (name, cond) => { results.push([name, !!cond]); console.log(`${cond ? '✓' : '✗'} ${name}`) }
const app = () => document.getElementById('app')

// Errores JS capturados
const jsErrors = []
window.addEventListener('error', (e) => jsErrors.push(e.message))
const origErr = console.error
console.error = (...a) => { jsErrors.push(String(a[0])); }

await wait(200)
check('Carga inicial: home renderizado', app().textContent.includes('Un hogar para tu mascota'))
check('Carga inicial: sin errores JS', jsErrors.length === 0)

// ---- Rutas ----
const routes = [
  ['#/buscar', 'hospedajes'],
  ['#/buscar?tipo=guarderia&ciudad=Bogotá', 'Guardería'],
  ['#/hospedaje/ph-01', 'Guardería Patitas Felices'],
  ['#/hospedaje/ph-07', 'Finca Los Cerros'],
  ['#/actividades', 'Convierte la estancia en una aventura'],
  ['#/login', 'Bienvenido de nuevo'],
  ['#/registro', 'Crea tu cuenta']
]
for (const [h, txt] of routes) {
  window.location.hash = h
  await wait(60)
  check(`Ruta ${h}`, app().textContent.includes(txt))
}

// ---- Selector "compartir con más mascotas" en el buscador ----
window.location.hash = '#/'
await wait(60)
const convSel = document.getElementById('sb-conv')
check('Buscador: opción compartir visible (Sí/No/Sin preferencia)', !!convSel && convSel.options.length === 3)
check('Buscador: interruptor "Cuidado en casa" eliminado del panel', document.getElementById('sb-casa') === null && !app().textContent.includes('Cuidado en casa</span>'))
// Filtro clásico con convivencia
const convSel2 = document.getElementById('sb-conv')
convSel2.value = 'individual'
const orb2 = document.querySelector('[data-a="do-search"]')
orb2.click()
await wait(80)
check('Buscador: filtra estancia individual', window.location.hash.includes('convivencia=individual') && app().textContent.includes('Estancia individual'))

// ---- Acceso restringido: /mensajes sin sesión → login ----
window.location.hash = '#/mensajes'
await wait(60)
check('Gate: /mensajes sin sesión redirige a login', window.location.hash === '#/login' && app().textContent.includes('Bienvenido de nuevo'))
check('Gate: guarda origen (ph_from)', window.localStorage.getItem('ph_from') === '#/mensajes')

// ---- Login demo ----
const demoBtn = [...app().querySelectorAll('button')].find((b) => b.textContent.includes('Entrar como dueño'))
demoBtn.click()
await wait(60)
check('Login demo: redirige al origen guardado', window.location.hash === '#/mensajes')
check('Login demo: navbar muestra cuenta', app().querySelector('.account-chip') !== null)
check('Login demo: chat con conversaciones', app().textContent.includes('Carolina Mejía'))

// ---- Enviar mensaje en el chat ----
const chatInput = document.getElementById('chat-msg')
chatInput.value = '¿Hay cupo para el 20 de agosto?'
document.getElementById('chat-send').disabled = false
document.querySelector('[data-form="chat"]').dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }))
await wait(100)
check('Chat: mensaje enviado', app().textContent.includes('¿Hay cupo para el 20 de agosto?'))

// ---- Reserva completa ----
window.location.hash = '#/hospedaje/ph-01'
await wait(60)
const reservarBtn = [...app().querySelectorAll('button')].find((b) => b.textContent.trim().startsWith('Reservar'))
reservarBtn.click() // sin fechas → abre calendario
await wait(60)
check('Reserva: abre calendario sin fechas', app().querySelector('.cal-day') !== null)
const daySel = () => [...app().querySelectorAll('.cal-day:not(:disabled)')]
const d1 = daySel()[2]; d1.click(); await wait(40) // elegir llegada (re-render)
const d2 = daySel()[5]; d2.click(); await wait(40) // re-consultar DOM y elegir salida
check('Cotización: desglose visible', app().textContent.includes('Tarifa de limpieza'))
const aplicar = [...app().querySelectorAll('button')].find((b) => b.textContent.trim() === 'Aplicar')
aplicar.click(); await wait(60)
const reservarBtn2 = [...app().querySelectorAll('button')].find((b) => b.textContent.trim().startsWith('Reservar'))
reservarBtn2.click(); await wait(60)
check('Confirmación: modal visible', app().textContent.includes('Confirma tu reserva'))
const confirmar = [...app().querySelectorAll('button')].find((b) => b.textContent.includes('Confirmar reserva'))
confirmar.click(); await wait(80)
check('Éxito: reserva confirmada', app().textContent.includes('¡Reserva confirmada!') && app().textContent.includes('PH-'))
const codigo = (app().textContent.match(/PH-[A-Z0-9]+/) || [])[0]
check('Éxito: código de reserva generado', !!codigo)

// ---- Mis reservas ----
window.location.hash = '#/mis-reservas'
await wait(60)
check('Mis reservas: muestra la reserva', app().textContent.includes('Confirmada') && app().textContent.includes(codigo))

// ---- Actividades: agregar al plan (ya con sesión) ----
window.location.hash = '#/actividades'
await wait(60)
const addBtn = [...app().querySelectorAll('button')].find((b) => b.getAttribute('aria-label')?.includes('Agregar'))
addBtn.click(); await wait(60)
check('Actividades: modal de fechas', app().textContent.includes('Agregar:') || app().textContent.includes('Elige las fechas'))
const apply2 = [...app().querySelectorAll('button')].find((b) => b.textContent.trim() === 'Aplicar')
if (apply2) { apply2.click(); await wait(50) }
const addPlan = [...app().querySelectorAll('button')].find((b) => b.textContent.includes('Agregar al plan'))
if (addPlan) { addPlan.click(); await wait(60) }
check('Actividades: plan con ítem', app().textContent.includes('Plan de actividades'))

// ---- Publicar actividad (rol anfitrión) ----
window.location.hash = '#/login'
await wait(60)
const hostBtn = [...app().querySelectorAll('button')].find((b) => b.textContent.includes('Entrar como anfitrión'))
hostBtn.click(); await wait(60)
window.location.hash = '#/actividades'
await wait(60)
const pubBtn = [...app().querySelectorAll('button')].find((b) => b.textContent.includes('Publicar actividad'))
pubBtn.click(); await wait(60)
check('Publicar: modal para anfitrión', app().querySelector('#pub-nombre') !== null)
// Cerrar el modal de publicar para dejar estado limpio
const cancelPub = [...app().querySelectorAll('.modal-footer .btn')].find((b) => b.textContent.trim() === 'Cancelar')
cancelPub.click(); await wait(40)
check('Publicar: modal se cierra', app().querySelector('#pub-nombre') === null)

// ---- Registro: validación ----
window.location.hash = '#/registro'
await wait(60)
document.querySelector('[data-form="register"]').dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }))
await wait(60)
check('Registro: valida campos', app().textContent.includes('Ingresa tu nombre completo') && app().textContent.includes('Debes aceptar los términos'))

// ---- Cierre de modales con scrim ----
window.location.hash = '#/hospedaje/ph-02'
await wait(60)
const openCalBtn = document.querySelector('[data-a="open-cal"]')
openCalBtn.click()
await wait(40)
const scrim = app().querySelector('.modal-scrim')
scrim.dispatchEvent(new window.MouseEvent('click', { bubbles: true }))
await wait(40)
check('Modal: cierra al hacer clic fuera', app().querySelector('.modal-scrim') === null)

// ---- Asistente IA (Dr. Pethouse) ----
window.location.hash = '#/'
await wait(60)
const fab = document.querySelector('.ai-fab')
check('IA: botón flotante "Consulta con IA" visible', !!fab && fab.textContent.includes('Consulta con IA'))
fab.click()
// Capturar sincrónicamente tras el clic (antes de que el sondeo del servidor re-renderice)
const styleFirst = (document.querySelector('.ai-modal') || { getAttribute: () => null }).getAttribute('style') || ''
check('IA: animación normal en la primera apertura', !styleFirst.includes('animation:none'))
await wait(60)
check('IA: modal del asistente se abre', app().textContent.includes('Dr. Pethouse'))
check('IA: mensaje de bienvenida del bot', app().textContent.includes('asistente de salud'))
check('IA: modo offline indicado (sin clave)', app().textContent.includes('Modo offline'))
check('IA: preguntas rápidas disponibles', document.querySelectorAll('.ai-chip').length >= 4)
// Pregunta por chip (modo offline → base de conocimiento local)
const chipVomito = [...app().querySelectorAll('.ai-chip')].find((b) => b.textContent.includes('vomita'))
chipVomito.click(); await wait(120)
check('IA: responde a "vomita" con consejo local', app().textContent.includes('vómito') || app().textContent.includes('veterinario'))
const styleAfter = (document.querySelector('.ai-modal') || { getAttribute: () => null }).getAttribute('style') || ''
check('IA: ventana estática en las respuestas (sin re-animación)', styleAfter.includes('animation:none'))
// Pregunta escrita por el formulario
const aiInput = document.getElementById('ai-msg')
aiInput.value = '¿Cada cuánto debo bañar a mi gato?'
document.querySelector('[data-form="ai"]').dispatchEvent(new window.Event('submit', { bubbles: true, cancelable: true }))
await wait(120)
check('IA: responde a pregunta de baño', app().textContent.includes('acicalan') || app().textContent.includes('gatos'))
// Panel de configuración
document.querySelector('[data-a="ai-cfg"]').click(); await wait(40)
check('IA: panel de configuración con campo de clave', !!document.getElementById('ai-key'))
check('IA: opción "API del servidor (Gemini)" disponible', [...document.querySelectorAll('#ai-prov option')].some((o) => o.textContent.includes('API del servidor')))
check('IA: campo URL de la API del servidor presente', !!document.getElementById('ai-srvurl'))
// Cambiar a "Gemini directo" para probar el guardado con clave
const provSel = document.getElementById('ai-prov')
provSel.value = 'gemini'
provSel.dispatchEvent(new window.Event('change', { bubbles: true }))
const aiKey = document.getElementById('ai-key')
aiKey.value = 'AIzaClaveDePrueba'
document.querySelector('[data-a="ai-save"]').click(); await wait(60)
check('IA: muestra "IA conectada" tras guardar clave', app().textContent.includes('IA conectada'))
// Volver a "API del servidor" (configuración recomendada por defecto)
document.querySelector('[data-a="ai-cfg"]').click(); await wait(40)
const provSel2 = document.getElementById('ai-prov')
provSel2.value = 'servidor'
provSel2.dispatchEvent(new window.Event('change', { bubbles: true }))
document.querySelector('[data-a="ai-save"]').click(); await wait(60)
check('IA: indicador de "Gemini vía API" o "Modo offline" con servidor', app().textContent.includes('Gemini vía API') || app().textContent.includes('Modo offline'))
// Cerrar modal
document.querySelector('[data-a="close-ai"]').click(); await wait(40)
check('IA: modal se cierra', app().querySelector('.ai-modal') === null)

// ---- Nuevo tipo: cuidado en casa del dueño ----
window.location.hash = '#/buscar'
await wait(60)
check('Buscar: chip "Cuidado en tu casa" disponible', app().textContent.includes('Cuidado en tu casa'))
window.location.hash = '#/buscar?tipo=domicilio'
await wait(60)
check('Buscar: filtra cuidado a domicilio (6 cuidadores)', document.querySelectorAll('.p-card').length === 6)
window.location.hash = '#/hospedaje/ph-13'
await wait(60)
check('Detalle: hospedaje a domicilio con nota "Cuidado en tu casa"', app().textContent.includes('Cuidadora a domicilio') && app().textContent.includes('Cuidado en tu casa') && app().textContent.includes('desplaza hasta tu residencia'))
check('Detalle: botón "En el mapa"', app().textContent.includes('En el mapa'))

// ---- Mapa ----
window.location.hash = '#/mapa'
await wait(60)
check('Mapa: vista se renderiza', app().textContent.includes('Mapa de hospedajes'))
check('Mapa: marcadores de todos los hospedajes (18)', document.querySelectorAll('.map-marker').length === 18)
check('Mapa: contorno de Colombia presente', !!document.querySelector('.map-svg-wrap path'))
const firstMarker = document.querySelector('[data-a="map-pick"]')
firstMarker.dispatchEvent(new window.MouseEvent('click', { bubbles: true }))
await wait(60)
check('Mapa: clic en marcador muestra tarjeta', app().textContent.includes('Hospedaje seleccionado') && app().textContent.includes('Ver hospedaje'))
window.location.hash = '#/mapa?ciudad=Bogotá'
await wait(60)
check('Mapa: filtro por ciudad (Bogotá = 6 marcadores)', document.querySelectorAll('.map-marker').length === 6)
check('Mapa: chip de ciudad activo', app().querySelector('.chip.active') !== null && app().textContent.includes('Bogotá'))
window.location.hash = '#/mapa?hosp=ph-02'
await wait(60)
check('Mapa: ?hosp selecciona el hospedaje', app().textContent.includes('Hospedaje seleccionado') && app().textContent.includes('Happy Paws'))

const fails = results.filter(([, ok]) => !ok).length
console.log(`\n${results.length - fails}/${results.length} verificaciones pasaron`)
console.log(`Errores JS capturados: ${jsErrors.filter(e => !e.includes('Warning')).length}`)
process.exit(fails || jsErrors.length ? 1 : 0)
