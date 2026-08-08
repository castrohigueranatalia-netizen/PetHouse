#!/usr/bin/env node
/* ============================================================
   PETHOUSE · API DE IA — conecta la plataforma con Google Gemini
   ------------------------------------------------------------
   Uso:
     1. Consigue una clave gratuita en aistudio.google.com
        → "Get API key" (modelo gemini-2.0-flash, ya viene por defecto)
     2. Crea un archivo .env en esta carpeta con:
          GEMINI_API_KEY=AIza...
        (o exporta la variable de entorno GEMINI_API_KEY,
         o guarda la clave en clave-gemini.txt)
     3. Ejecuta:
          node servidor-ia.js
        y abre  http://localhost:3000

   Endpoints:
     GET  /api/ia/estado   → estado de la API (clave configurada, modelo)
     POST /api/ia          → { "consulta": "Mi perro vomita..." }
                             → { "respuesta": "..." }
     OPTIONS /api/ia       → CORS (permite usarlo desde cualquier página)

   La plataforma (index.html) usa este endpoint por defecto; la clave
   de Gemini vive solo en el servidor, nunca en el navegador.
   ============================================================ */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');

const DIR = __dirname;
const PORT = Number(process.env.PORT || 3000);

/* ---------- Clave y modelo (env → .env → clave-gemini.txt) ---------- */
function leerClave() {
  if (process.env.GEMINI_API_KEY) return process.env.GEMINI_API_KEY.trim();
  try {
    const txt = fs.readFileSync(path.join(DIR, '.env'), 'utf8');
    const m = txt.match(/^\s*GEMINI_API_KEY\s*=\s*(.+)\s*$/m);
    if (m) return m[1].trim();
  } catch (e) { /* sin archivo .env */ }
  try {
    const t = fs.readFileSync(path.join(DIR, 'clave-gemini.txt'), 'utf8').trim();
    if (t) return t;
  } catch (e) { /* sin archivo de clave */ }
  return null;
}
const CLAVE = leerClave();
const MODELO = process.env.GEMINI_MODEL || 'gemini-2.0-flash';

/* ---------- Prompt del asistente (igual que en la app) ---------- */
const SISTEMA =
  'Eres "Dr. Pethouse", asistente de salud y bienestar de mascotas de la plataforma Pethouse, ' +
  'un servicio de hospedaje para mascotas en Colombia. Respondes en español, de forma clara, ' +
  'cálida y breve (3 a 6 frases). Ayudas con dudas de salud, nutrición, comportamiento, higiene ' +
  'y cuidados de perros y gatos. Si la consulta tiene signos de alarma (sangre, convulsiones, ' +
  'dificultad para respirar, ingestión de tóxicos, vómito o diarrea persistentes, decaimiento, ' +
  'falta de apetito prolongada), di claramente que debe acudir de inmediato a un veterinario y ' +
  'menciona las señales de alarma. Nunca des dosis de medicamentos y recuerda siempre que no ' +
  'sustituyes al veterinario.';

/* ---------- Llamada a Google Gemini ---------- */
async function preguntarGemini(consulta) {
  const url =
    'https://generativelanguage.googleapis.com/v1beta/models/' +
    encodeURIComponent(MODELO) +
    ':generateContent?key=' +
    encodeURIComponent(CLAVE);
  const res = await fetch(url, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({
      systemInstruction: { parts: [{ text: SISTEMA }] },
      contents: [{ role: 'user', parts: [{ text: consulta }] }],
      generationConfig: { temperature: 0.5, maxOutputTokens: 500 }
    }),
    signal: AbortSignal.timeout(30000)
  });
  const data = await res.json().catch(() => ({}));
  if (!res.ok) {
    const msg = (data && data.error && data.error.message) || 'HTTP ' + res.status;
    throw new Error(msg);
  }
  const partes =
    data && data.candidates && data.candidates[0] &&
    data.candidates[0].content && data.candidates[0].content.parts;
  const texto = partes ? partes.map((p) => p.text || '').join('') : '';
  if (!texto.trim()) throw new Error('Gemini no devolvió contenido');
  return texto.trim();
}

/* ---------- CORS ---------- */
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'Content-Type'
};

/* ---------- Archivos estáticos (la propia plataforma HTML) ---------- */
const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.mjs': 'text/javascript; charset=utf-8',
  '.json': 'application/json; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.txt': 'text/plain; charset=utf-8'
};

function servirEstatico(req, res, pathname) {
  let rel = decodeURIComponent(pathname);
  if (rel === '/') rel = '/index.html';
  const filePath = path.normalize(path.join(DIR, rel));
  if (filePath !== DIR && !filePath.startsWith(DIR + path.sep)) {
    res.writeHead(403, CORS);
    res.end('Prohibido');
    return;
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, CORS);
      res.end('No encontrado');
      return;
    }
    const ext = path.extname(filePath).toLowerCase();
    res.writeHead(200, Object.assign({}, CORS, { 'Content-Type': MIME[ext] || 'application/octet-stream' }));
    res.end(data);
  });
}

/* ---------- Servidor ---------- */
const server = http.createServer((req, res) => {
  const url = new URL(req.url, 'http://localhost');
  const pathname = url.pathname;

  if (req.method === 'OPTIONS') {
    res.writeHead(204, CORS);
    res.end();
    return;
  }

  /* Estado de la API */
  if (req.method === 'GET' && pathname === '/api/ia/estado') {
    res.writeHead(200, Object.assign({}, CORS, { 'Content-Type': 'application/json; charset=utf-8' }));
    res.end(JSON.stringify({ configurada: !!CLAVE, modelo: MODELO, proveedor: 'gemini', api: 'servidor-ia' }));
    return;
  }

  /* Consulta a Gemini */
  if (req.method === 'POST' && pathname === '/api/ia') {
    let body = '';
    req.on('data', (c) => {
      body += c;
      if (body.length > 20000) req.destroy();
    });
    req.on('end', async () => {
      try {
        const data = JSON.parse(body || '{}');
        const consulta = String(data.consulta || '').trim();
        if (!consulta) {
          res.writeHead(400, CORS);
          res.end(JSON.stringify({ error: 'Falta la consulta.' }));
          return;
        }
        if (!CLAVE) {
          res.writeHead(503, CORS);
          res.end(JSON.stringify({ error: 'El servidor no tiene clave de Gemini. Crea un archivo .env con GEMINI_API_KEY=AIza…' }));
          return;
        }
        const respuesta = await preguntarGemini(consulta);
        res.writeHead(200, Object.assign({}, CORS, { 'Content-Type': 'application/json; charset=utf-8' }));
        res.end(JSON.stringify({ respuesta }));
      } catch (err) {
        res.writeHead(502, CORS);
        res.end(JSON.stringify({ error: String(err.message || err) }));
      }
    });
    return;
  }

  /* El resto: la plataforma HTML */
  servirEstatico(req, res, pathname);
});

server.listen(PORT, () => {
  console.log('');
  console.log('🐾 Pethouse · API de IA (Google Gemini)');
  console.log('   Plataforma:  http://localhost:' + PORT);
  console.log('   API:         POST http://localhost:' + PORT + '/api/ia');
  console.log('   Estado:      GET  http://localhost:' + PORT + '/api/ia/estado');
  console.log('   Clave Gemini: ' + (CLAVE ? '✓ configurada (modelo ' + MODELO + ')' : '✗ NO configurada — crea un archivo .env con GEMINI_API_KEY=AIza…'));
  console.log('');
});
