// ============================================================
// PETHOUSE API · URLs firmadas para archivos privados (verificación de anfitrión)
//
// La cédula, el certificado de antecedentes y las fotos de la persona/vivienda de una
// verificación de anfitrión son el dato más sensible de toda la app — antes se guardaban
// junto con las demás fotos (hospedaje, mascota, perfil) en /uploads, servidas
// públicamente por express.static sin ningún control de acceso: cualquiera con la URL
// exacta (un UUID) podía verlas, sin necesidad de haber iniciado sesión.
//
// Ahora esos archivos viven en una carpeta APARTE que express.static nunca sirve (ver
// uploadsPrivadoDir en routes/subidas.js), y solo se pueden leer con una URL firmada de
// corta duración — el mismo patrón que usan S3/Cloudinary para "presigned URLs". Cada vez
// que el servidor le devuelve al cliente la ficha de una verificación (la suya propia o,
// para un admin, la de alguien en revisión), firma la URL de cada foto con una fecha de
// vencimiento (`firmarUrlPrivada`/`firmarUrlsPrivadas`); `verificarFirma` es lo que valida
// esa firma en routes/subidas.js antes de servir el archivo de verdad.
//
// Se eligió una URL firmada por query string (y no exigir "Authorization: Bearer" en la
// petición) porque el componente que la app usa para mostrar CUALQUIER imagen
// (PHCachedAsyncImage) hace un `URLSession.shared.data(from: url)` simple, sin adjuntar
// el token de sesión — cambiar eso habría significado tocar el componente que muestra
// TODAS las fotos de la app, con el riesgo de romper algo que hoy funciona bien. Con la
// firma en la URL, ese componente no necesita cambiar nada: la URL en sí ya es la llave,
// y esa llave vence sola a los pocos minutos.
// ============================================================
import crypto from 'node:crypto'
import { JWT_SECRET } from '../config.js'

export const PREFIJO_PRIVADO = '/privado/verificacion/'
const VIGENCIA_MS = 15 * 60 * 1000 // 15 min — de sobra para que la app cargue la imagen

function firmar(archivo, exp) {
  return crypto.createHmac('sha256', JWT_SECRET).update(`${archivo}:${exp}`).digest('hex')
}

// "/privado/verificacion/xxx.jpg" → "/privado/verificacion/xxx.jpg?exp=...&sig=...".
// Cualquier otro valor (foto pública, null/undefined) se devuelve tal cual — así se puede
// llamar sin distinguir de antemano qué campos son privados y cuáles no.
export function firmarUrlPrivada(url) {
  if (!url || !url.startsWith(PREFIJO_PRIVADO)) return url
  const archivo = url.slice(PREFIJO_PRIVADO.length)
  const exp = Date.now() + VIGENCIA_MS
  const sig = firmar(archivo, exp)
  return `${url}?exp=${exp}&sig=${sig}`
}

export function firmarUrlsPrivadas(urls) {
  return (urls || []).map(firmarUrlPrivada)
}

// Firma TODOS los campos de foto de una fila de `verificaciones_anfitrion` a la vez —
// usado antes de responder con esa fila desde cualquier ruta (propia o de admin).
export function firmarVerificacion(v) {
  if (!v) return v
  return {
    ...v,
    certificado_policial_url: firmarUrlPrivada(v.certificado_policial_url),
    fotos_persona: firmarUrlsPrivadas(v.fotos_persona),
    fotos_vivienda: firmarUrlsPrivadas(v.fotos_vivienda)
  }
}

export function verificarFirma(archivo, exp, sig) {
  if (!archivo || !exp || !sig) return false
  if (Date.now() > Number(exp)) return false
  const esperada = firmar(archivo, exp)
  const a = Buffer.from(String(sig))
  const b = Buffer.from(esperada)
  // Longitud distinta ya significa que no coincide, pero se compara con
  // timingSafeEqual (en vez de ===) para no filtrar por temporización cuánto de la
  // firma acertó un intento inválido.
  return a.length === b.length && crypto.timingSafeEqual(a, b)
}
