// ============================================================
// PETHOUSE API · Generación de CSV para los reportes descargables del panel de admin
//
// A mano, sin librería: el formato es simple (comas + comillas dobles cuando hace falta
// escapar) y así no se agrega una dependencia solo para esto. El BOM (﻿) al principio
// es a propósito — sin él, Excel (Mac y Windows) a veces interpreta los acentos como
// caracteres raros al abrir el archivo directamente en vez de importarlo.
// ============================================================

function escaparCampo(valor) {
  const texto = valor === null || valor === undefined ? '' : String(valor)
  return /[",\n]/.test(texto) ? `"${texto.replace(/"/g, '""')}"` : texto
}

// `columnas`: [{ campo: 'nombre_en_la_fila', etiqueta: 'Encabezado visible' }, ...]
export function aCSV(columnas, filas) {
  const encabezado = columnas.map(c => escaparCampo(c.etiqueta)).join(',')
  const lineas = filas.map(fila => columnas.map(c => escaparCampo(fila[c.campo])).join(','))
  return '﻿' + [encabezado, ...lineas].join('\r\n')
}
