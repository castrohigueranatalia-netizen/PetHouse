// ============================================================
// PETHOUSE API · Días hábiles para plazos legales de privacidad (Ley 1581 de 2012)
//
// Solo descuenta sábados y domingos, NO festivos colombianos — es una aproximación
// conservadora (el plazo real nunca es más corto que el que calcula esto), no un cálculo
// legal exacto. Suficiente para avisar en el panel cuándo se está por vencer una solicitud.
// ============================================================

export function diasHabilesPorCategoria(categoria) {
  // Art. 14: las consultas (ej. "conocer mis datos") tienen 10 días hábiles.
  // Art. 15: los reclamos (corregir, eliminar, y cualquier otra queja) tienen 15.
  return categoria === 'conocer' ? 10 : 15
}

export function sumarDiasHabiles(fechaInicio, diasHabiles) {
  const fecha = new Date(fechaInicio)
  let sumados = 0
  while (sumados < diasHabiles) {
    fecha.setUTCDate(fecha.getUTCDate() + 1)
    const diaSemana = fecha.getUTCDay() // 0 = domingo, 6 = sábado
    if (diaSemana !== 0 && diaSemana !== 6) sumados++
  }
  return fecha
}
