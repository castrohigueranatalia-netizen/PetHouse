// ============================================================
// PETHOUSE API · Módulo Subidas (imágenes de perfil, mascota, hospedaje, verificación)
// POST /api/subidas  (multipart/form-data, campo "archivo")
// GET  /privado/verificacion/:archivo?exp=...&sig=...  (fotos de verificación, firmadas)
//
// Antes no existía ningún endpoint de subida (gap BLOQUEANTE #1, ver
// ARCHITECTURE_AUDIT.md §6): un anfitrión no podía publicar fotos reales ni un dueño poner
// foto de perfil/mascota. Contrato consumido ya por
// PetHouseiOS/Networking/Services/ImagenesService.swift (campo "archivo", 201 { url }).
//
// Almacenamiento: disco local servido como estático (ver app.js: `/uploads` →
// express.static(uploadsDir)), NO S3/Cloudinary. Es la elección correcta para un MVP: cero
// credenciales/cuentas de terceros que provisionar, y el volumen esperado (fotos de un
// marketplace en lanzamiento) no lo justifica todavía. docs/ARQUITECTURA.md ya señala
// S3/Cloudinary como la migración natural cuando el tráfico lo amerite — cambiar el
// storage detrás de este mismo endpoint no requiere tocar el cliente (sigue recibiendo una
// URL en la misma forma).
//
// Fotos de VERIFICACIÓN DE ANFITRIÓN (cédula, certificado de antecedentes, fotos de la
// persona/vivienda) son un caso aparte: es el dato más sensible de toda la app, así que NO
// van a `uploadsDir` (público, servido sin control de acceso) sino a `uploadsPrivadoDir`,
// una carpeta que express.static nunca toca. Solo se leen con una URL firmada de corta
// duración — ver lib/urlsPrivadas.js para el porqué completo del diseño. El cliente pide
// esto mandando `POST /api/subidas?tipo=verificacion` en vez de `POST /api/subidas`.
// ============================================================
import { Router } from 'express'
import multer from 'multer'
import sharp from 'sharp'
import { fileTypeFromFile } from 'file-type'
import { randomUUID } from 'node:crypto'
import path from 'node:path'
import fs from 'node:fs'
import { fileURLToPath } from 'node:url'
import { auth } from '../middleware/middleware.js'
import { PUBLIC_BASE_URL } from '../config.js'
import { PREFIJO_PRIVADO, verificarFirma } from '../lib/urlsPrivadas.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
export const uploadsDir = path.join(__dirname, '..', '..', 'uploads')
export const uploadsPrivadoDir = path.join(__dirname, '..', '..', 'uploads-privado')
fs.mkdirSync(uploadsDir, { recursive: true })
fs.mkdirSync(uploadsPrivadoDir, { recursive: true })

// image/* para fotos (perfil, mascota, hospedaje, verificación de anfitrión) y
// application/pdf para documentos (ej. certificado de antecedentes policiales, si el
// anfitrión prefiere adjuntar el PDF original en vez de una foto del documento — el
// cliente iOS del MVP solo ofrece adjuntar fotos, pero el endpoint ya acepta ambos).
const TIPOS_PERMITIDOS = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif', 'application/pdf'])
const EXTENSION_POR_TIPO = {
  'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp',
  'image/heic': '.heic', 'image/heif': '.heif', 'application/pdf': '.pdf'
}

const storage = multer.diskStorage({
  // `req.query.tipo`, no `req.body.tipo`: multer procesa el multipart en streaming, en el
  // mismo orden en que llegan las partes — un campo de texto que viniera DESPUÉS del
  // archivo en el body todavía no estaría disponible acá. El query string, en cambio, ya
  // se conoce completo desde el principio de la petición.
  destination: (req, _file, cb) => cb(null, req.query.tipo === 'verificacion' ? uploadsPrivadoDir : uploadsDir),
  filename: (_req, file, cb) => {
    const ext = EXTENSION_POR_TIPO[file.mimetype] || path.extname(file.originalname) || ''
    cb(null, `${randomUUID()}${ext}`)
  }
})

const upload = multer({
  storage,
  limits: { fileSize: 8 * 1024 * 1024 }, // 8MB
  fileFilter: (_req, file, cb) => {
    if (!TIPOS_PERMITIDOS.has(file.mimetype)) {
      return cb(new Error('Formato no soportado. Sube una imagen JPEG, PNG, WEBP, HEIC o un PDF.'))
    }
    cb(null, true)
  }
})

// Recomprime una imagen ya guardada en disco: reduce su tamaño máximo, la pasa a JPEG y
// (con `.rotate()`, sin pedirle que conserve metadata) le quita los metadatos EXIF —
// incluida la ubicación GPS, si la cámara la guardó, algo que ni el usuario ni PetHouse
// necesitan que viaje pegado a la foto. Devuelve el nombre del archivo final (puede
// terminar en .jpg aunque haya entrado como .png/.heic/etc.) o `null` si no se pudo
// recomprimir (formato raro, HEIC sin soporte en este servidor, etc.) — en ese caso se dice
// que se deje el original tal cual: mejor una foto pesada que perder la subida por completo.
//
// Nota: el cliente iOS (ver Core/Utils/ImagenComprimida.swift) YA comprime cada foto antes
// de subirla (máx. 1600px, JPEG calidad 0.7) — así que para la app de hoy esto es una
// segunda pasada redundante. Se agrega igual como red de seguridad del lado del servidor:
// cubre cualquier subida que no pase por ese camino (una futura integración, alguien
// llamando la API directo) y, sobre todo, es la única capa que de verdad limpia el EXIF —
// el cliente no lo hace hoy.
export async function recomprimir(archivo, carpeta) {
  const rutaOriginal = path.join(carpeta, archivo)
  const base = path.basename(archivo, path.extname(archivo))
  const nombreFinal = `${base}.jpg`
  const rutaFinal = path.join(carpeta, nombreFinal)
  // Sharp no permite leer y escribir el MISMO archivo a la vez — pasa justo cuando la
  // subida ya venía en .jpg (nombreFinal == archivo). Se escribe siempre a un archivo
  // temporal aparte y se renombra al final, sea cual sea la extensión de entrada.
  const rutaTemporal = path.join(carpeta, `${base}.tmp-${randomUUID()}.jpg`)
  try {
    await sharp(rutaOriginal)
      .rotate()
      .resize({ width: 1600, height: 1600, fit: 'inside', withoutEnlargement: true })
      .jpeg({ quality: 82 })
      .toFile(rutaTemporal)
    fs.renameSync(rutaTemporal, rutaFinal) // reemplaza el destino de forma atómica si ya existía
    if (rutaOriginal !== rutaFinal) fs.unlinkSync(rutaOriginal)
    return nombreFinal
  } catch (err) {
    console.error('No se pudo recomprimir la imagen (se deja el original):', err.message)
    if (fs.existsSync(rutaTemporal)) fs.unlinkSync(rutaTemporal)
    return null
  }
}

const r = Router()

r.post('/', auth, (req, res, next) => {
  upload.single('archivo')(req, res, async (err) => {
    if (err instanceof multer.MulterError) {
      const mensaje = err.code === 'LIMIT_FILE_SIZE' ? 'La imagen no puede pesar más de 8MB.' : err.message
      return res.status(400).json({ error: mensaje })
    }
    if (err) return res.status(400).json({ error: err.message })
    if (!req.file) return res.status(400).json({ error: 'Falta el archivo (campo "archivo").' })

    const carpeta = req.query.tipo === 'verificacion' ? uploadsPrivadoDir : uploadsDir
    const rutaGuardada = path.join(carpeta, req.file.filename)

    // El filtro de multer (`fileFilter` arriba) solo mira el `Content-Type` que declaró
    // quien sube el archivo — un campo que pone el cliente, así que se puede falsificar
    // (ej. subir un ejecutable con Content-Type: image/jpeg). Acá se abren los primeros
    // bytes del archivo YA guardado y se detecta el formato real por su firma binaria
    // (magic number) — si no coincide con ninguno de los tipos permitidos, se rechaza y se
    // borra, sin importar lo que decía el header.
    const tipoReal = await fileTypeFromFile(rutaGuardada).catch(() => undefined)
    if (!tipoReal || !TIPOS_PERMITIDOS.has(tipoReal.mime)) {
      fs.unlinkSync(rutaGuardada)
      return res.status(400).json({ error: 'El archivo no es una imagen o PDF válido.' })
    }

    let nombreArchivo = req.file.filename
    if (req.file.mimetype.startsWith('image/')) {
      const comprimido = await recomprimir(req.file.filename, carpeta)
      if (comprimido) nombreArchivo = comprimido
    }

    // Con PUBLIC_BASE_URL configurado (producción, dominio fijo): URL absoluta con ese
    // dominio. SIN configurar (caso normal en desarrollo): URL RELATIVA (`/uploads/...`),
    // NO construida con el host de esta petición como antes — ese host es la IP de red
    // local de la Mac en ese instante (ej. "192.168.1.5"), que cambia cada vez que se
    // reconecta al wifi/reinicia el router. Guardar esa IP en la URL significa que toda
    // foto subida antes de un cambio de IP queda rota (bug real, visto en producción de
    // este mismo MVP). Con la URL relativa, el cliente la resuelve SIEMPRE contra la IP
    // ACTUAL configurada (ver `MediaURL.resolver` en iOS), así que sigue funcionando sin
    // importar cuántas veces cambie la red.
    const rutaRelativa = req.query.tipo === 'verificacion'
      ? `${PREFIJO_PRIVADO}${nombreArchivo}`
      : `/uploads/${nombreArchivo}`
    const url = PUBLIC_BASE_URL ? `${PUBLIC_BASE_URL}${rutaRelativa}` : rutaRelativa
    res.status(201).json({ url })
  })
})

// ---- Sirve una foto de verificación, solo con una URL firmada y vigente ----
// Sin `auth` a propósito — la firma en la URL YA es la credencial (ver lib/urlsPrivadas.js
// para el porqué). Una URL sin firma, con firma incorrecta, o vencida (15 min) no sirve
// para nada: no hay forma de "adivinar" una firma válida sin conocer JWT_SECRET.
export const verificacionPrivadaRouter = Router()
verificacionPrivadaRouter.get('/:archivo', (req, res) => {
  const { archivo } = req.params
  const { exp, sig } = req.query
  // El nombre siempre lo genera el servidor con randomUUID() + una extensión conocida (ver
  // `filename` arriba) — cualquier otra forma (con "..", "/", etc.) es, en el mejor de los
  // casos, un enlace corrupto y, en el peor, un intento de salirse de uploadsPrivadoDir.
  if (!/^[a-f0-9-]{36}\.(jpg|png|webp|heic|heif|pdf)$/i.test(archivo)) {
    return res.status(400).json({ error: 'Nombre de archivo inválido.' })
  }
  if (!verificarFirma(archivo, exp, sig)) {
    return res.status(403).json({ error: 'Enlace inválido o vencido.' })
  }
  res.sendFile(path.join(uploadsPrivadoDir, archivo), (err) => {
    if (err && !res.headersSent) res.status(404).json({ error: 'Archivo no encontrado.' })
  })
})

export default r
