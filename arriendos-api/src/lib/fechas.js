// ============================================================
// ARRIENDOS CARTAGENA API · Utilidades de fecha
// ------------------------------------------------------------
// Los eventos de un calendario iCal son "solo fecha" (sin hora ni zona
// horaria): se leen y escriben siempre en UTC para no correr el día por
// culpa de la hora local del servidor.
// ============================================================

export function aFechaSQL(fecha) {
  const d = new Date(fecha)
  const yyyy = d.getUTCFullYear()
  const mm = String(d.getUTCMonth() + 1).padStart(2, '0')
  const dd = String(d.getUTCDate()).padStart(2, '0')
  return `${yyyy}-${mm}-${dd}`
}

export function aFechaICS(fecha) {
  return aFechaSQL(fecha).replaceAll('-', '')
}
