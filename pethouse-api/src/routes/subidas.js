// ============================================================
// PETHOUSE API · Módulo Subidas (imágenes de perfil, mascota, hospedaje)
// POST /api/subidas  (multipart/form-data, campo "archivo")
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
// ============================================================
import { Router } from 'express'
import multer from 'multer'
import { randomUUID } from 'node:crypto'
import path from 'node:path'
import fs from 'node:fs'
import { fileURLToPath } from 'node:url'
import { auth } from '../middleware/middleware.js'
import { PUBLIC_BASE_URL } from '../config.js'

const __dirname = path.dirname(fileURLToPath(import.meta.url))
export const uploadsDir = path.join(__dirname, '..', '..', 'uploads')
fs.mkdirSync(uploadsDir, { recursive: true })

const TIPOS_PERMITIDOS = new Set(['image/jpeg', 'image/png', 'image/webp', 'image/heic', 'image/heif'])
const EXTENSION_POR_TIPO = {
  'image/jpeg': '.jpg', 'image/png': '.png', 'image/webp': '.webp',
  'image/heic': '.heic', 'image/heif': '.heif'
}

const storage = multer.diskStorage({
  destination: (_req, _file, cb) => cb(null, uploadsDir),
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
      return cb(new Error('Formato no soportado. Sube una imagen JPEG, PNG, WEBP o HEIC.'))
    }
    cb(null, true)
  }
})

const r = Router()

r.post('/', auth, (req, res, next) => {
  upload.single('archivo')(req, res, (err) => {
    if (err instanceof multer.MulterError) {
      const mensaje = err.code === 'LIMIT_FILE_SIZE' ? 'La imagen no puede pesar más de 8MB.' : err.message
      return res.status(400).json({ error: mensaje })
    }
    if (err) return res.status(400).json({ error: err.message })
    if (!req.file) return res.status(400).json({ error: 'Falta el archivo (campo "archivo").' })

    const url = `${PUBLIC_BASE_URL}/uploads/${req.file.filename}`
    res.status(201).json({ url })
  })
})

export default r
