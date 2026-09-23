// ============================================================
// PETHOUSE API · "Hoy" en la zona horaria de Bogotá
// ------------------------------------------------------------
// La app opera solo en Bogotá (ver LOCALIDADES_BOGOTA en routes/hospedajes.js) — "hoy" debe
// significar lo mismo para todos, sin importar en qué timezone corra el proceso de Node o
// la sesión de Postgres (UTC por defecto en este proyecto).
//
// Bug real que esto reemplaza: `new Date(desde) < new Date(new Date().toDateString())`
// mezclaba dos interpretaciones distintas de la misma fecha — `new Date("YYYY-MM-DD")`
// SIEMPRE se parsea en UTC, pero `new Date(unTextoNoISO)` (como el que devuelve
// `toDateString()`) se parsea en la zona horaria LOCAL del proceso. Con el servidor en
// UTC, o corriendo en Bogotá (UTC-5) como en desarrollo local, esa mezcla podía rechazar
// "hoy" como si fuera una fecha pasada en las últimas horas del día — confirmado con
// pruebas reales, no solo en teoría.
// ============================================================

// Devuelve la fecha de HOY en Bogotá como "YYYY-MM-DD" — comparable directo como texto
// contra columnas DATE/strings YYYY-MM-DD porque el formato ISO ordena igual como texto
// que como fecha.
export function hoyBogota() {
  return new Intl.DateTimeFormat('en-CA', { timeZone: 'America/Bogota' }).format(new Date())
}
