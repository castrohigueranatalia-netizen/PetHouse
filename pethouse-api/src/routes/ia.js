// ============================================================
// PETHOUSE API · Módulo IA (proxy seguro hacia Google Gemini)
// GET  /api/ia/estado · POST /api/ia  { consulta }
// La clave vive solo en el servidor (.env), nunca en el cliente.
// ============================================================
import { Router } from 'express'
import { GEMINI_KEY, GEMINI_MODEL } from '../config.js'

const r = Router()

const SISTEMA =
  'Eres "Dr. Pethouse", asistente de salud y bienestar de mascotas de la plataforma Pethouse, ' +
  'un servicio de hospedaje para mascotas en Colombia. Respondes en español, de forma clara, ' +
  'cálida y breve (3 a 6 frases). Ayudas con dudas de salud, nutrición, comportamiento, higiene ' +
  'y cuidados de perros y gatos. Si la consulta tiene signos de alarma (sangre, convulsiones, ' +
  'dificultad para respirar, ingestión de tóxicos, vómito o diarrea persistentes, decaimiento, ' +
  'falta de apetito prolongada), di claramente que debe acudir de inmediato a un veterinario y ' +
  'menciona las señales de alarma. Nunca des dosis de medicamentos y recuerda siempre que no ' +
  'sustituyes al veterinario.'

r.get('/estado', (_req, res) => {
  res.json({ configurada: !!GEMINI_KEY, modelo: GEMINI_MODEL, proveedor: 'gemini', api: 'pethouse-api' })
})

r.post('/', async (req, res) => {
  const consulta = String(req.body?.consulta || '').trim()
  if (!consulta) return res.status(400).json({ error: 'Falta la consulta.' })
  if (!GEMINI_KEY) {
    return res.status(503).json({ error: 'El servidor no tiene clave de Gemini configurada (GEMINI_API_KEY).' })
  }

  try {
    const url = `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(GEMINI_MODEL)}:generateContent?key=${encodeURIComponent(GEMINI_KEY)}`
    const rp = await fetch(url, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({
        systemInstruction: { parts: [{ text: SISTEMA }] },
        contents: [{ role: 'user', parts: [{ text: consulta }] }],
        generationConfig: { temperature: 0.5, maxOutputTokens: 500 }
      }),
      signal: AbortSignal.timeout(30000)
    })
    const data = await rp.json().catch(() => ({}))
    if (!rp.ok) throw new Error(data?.error?.message || 'HTTP ' + rp.status)

    const partes = data?.candidates?.[0]?.content?.parts
    const texto = partes ? partes.map((p) => p.text || '').join('') : ''
    if (!texto.trim()) throw new Error('Gemini no devolvió contenido')

    res.json({ respuesta: texto.trim() })
  } catch (err) {
    res.status(502).json({ error: String(err.message || err) })
  }
})

export default r
