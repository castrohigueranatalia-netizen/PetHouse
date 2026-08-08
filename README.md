# 🐾 Pethouse — Versión HTML autocontenida

**`index.html`** es la plataforma completa en **un solo archivo** de HTML con CSS y JavaScript
vanilla embebidos y **todas las imágenes incrustadas en base64** (funciona sin internet y sin servidor).

## Cómo usarla

| Acción | Cómo |
|---|---|
| **Abrir la plataforma** | Doble clic en `index.html` (se abre en cualquier navegador) |
| **Ver el código** | Abrir `index.html` en un editor — el CSS está en `<style>`, el JS en `<script>` |
| **Probar automáticamente** | `npm install && npm test` (27 verificaciones con jsdom) |
| **Reconstruir el archivo** | `python3 build.py` (re-inyecta las imágenes en `_src/`) |

## Estructura interna del archivo

```
index.html (882 KB, autocontenido)
├── <style>      Sistema de diseño MD3: tokens (#FB3F57 coral, #2A2F35 tinta),
│                botones, campos, chips, modales, calendario, chat, cards…
├── <script>
│   ├── Datos    IMG (base64), iconos SVG MD, 12 hospedajes, hosts, reseñas, actividades
│   ├── Estado   Sesión, favoritos, reservas, plan de actividades, chat (localStorage
│   │            con fallback a memoria si el navegador lo bloquea)
│   └── Vistas   Router por hash: #/  #/buscar  #/hospedaje/:id  #/actividades
│                #/login  #/registro  #/mensajes  #/mis-reservas
```

## Funcionalidades incluidas

- **Buscador pill**: ciudad + fechas (calendario de rango) + preferencia de convivencia.
- **Filtros**: tipo de alojamiento (Guardería / Veterinaria / Casa campestre / Apartamento /
  **Cuidado en tu casa**), convivencia (puede compartir / estancia individual), ordenamiento; todo en la URL.
- **Cuidado en tu casa (pet sitter a domicilio)**: cuidador que se desplaza a la residencia
  del dueño (3 hospedajes: Bogotá, Medellín y Cali, con reseñas propias).
- **Mapa interactivo de Colombia** (`#/mapa`): contorno SVG embebido (funciona offline) con un
  marcador por hospedaje según su ciudad, coloreados por tipo; filtros por ciudad y tipo,
  clic en el marcador para ver la tarjeta del hospedaje, y `#/mapa?hosp=ph-XX` para preseleccionarlo.
  También hay botones "Ver mapa" en la búsqueda y "En el mapa" en el detalle.
- **Detalle**: cotización por día (precio × noches + limpieza + servicio 10%), rating 64px,
  reseñas con estrellas, servicios, reglas, host con Superanfitrión.
- **Actividades caninas**: catálogo, agregar al plan con fechas y publicar (rol anfitrión).
- **Chat interno** dueño ⇄ anfitrión con respuesta automática simulada y no-leídos.
- **Login** (correo + contraseña) y **registro** (datos personales + cuenta) con validación.
- **Acceso restringido**: reservar / chatear / agregar actividades exigen sesión; tras el
  login se vuelve al punto exacto donde iba el usuario.

## 🤖 Consulta con IA ("Dr. Pethouse") — conectada a Gemini por API

Botón flotante **"Consulta con IA"** (abajo a la derecha) que abre un chat con un asistente
de salud y cuidados de mascotas:

- **Conectada a Google Gemini a través de la API del servidor** (`servidor-ia.js`):
  el chat llama a `POST /api/ia`, el servidor llama a Gemini con la clave guardada en `.env`
  y devuelve la respuesta. **La clave nunca sale del servidor** (forma segura y recomendada).

### Cómo activar la conexión (2 minutos)

```bash
cd pethouse-html
# 1. Clave gratuita: https://aistudio.google.com → "Get API key"
echo "GEMINI_API_KEY=AIzaTUCLAVE" > .env      # o copia .env.example a .env
node servidor-ia.js                            # o: npm run ia
# Abre http://localhost:3000  → el indicador del chat dirá "● Gemini vía API"
```

Endpoints de la API:
- `GET  /api/ia/estado` → `{ configurada: true, modelo: "gemini-2.0-flash", ... }`
- `POST /api/ia` → `{ "consulta": "Mi perro vomita" }` → `{ "respuesta": "..." }`
- CORS habilitado; el mismo servidor también sirve la plataforma (`index.html`).

**Alternativas** (panel ⚙ dentro del chat):
- *Gemini directo*: pega tu clave en el navegador (la clave queda en tu equipo).
- *OpenAI / compatible*: URL base + clave.
- Sin servidor ni clave → **modo offline** con base de conocimiento local de 18 temas
  (vómito, diarrea, fiebre, intoxicaciones, pulgas, baño, alimentación, vacunas, ansiedad,
  gatos, cachorros, geriátricos, viajes, emergencias…).

Preguntas rápidas con un toque, indicador de escritura y aviso permanente de que la IA
no sustituye al veterinario.

### Cuentas demo

- Dueño: `cliente@pethouse.co` / `demo123` (o botón "Entrar como dueño" en `#/login`)
- Anfitrión: `anfitrion@pethouse.co` / `demo123`

> La versión React con el mismo diseño vive en `/home/user/pethouse` (npm run dev).
