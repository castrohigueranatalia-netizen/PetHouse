# 🐾 Pethouse API — Node.js + Express + PostgreSQL/PostGIS

API REST que conecta la plataforma Pethouse con la base de datos real.
Sigue la arquitectura de [`../docs/ARQUITECTURA.md`](../docs/ARQUITECTURA.md) (monolito modular, 7 módulos).

## Requisitos

- Node.js 18+
- PostgreSQL 14+ con PostGIS (levántala con [`../db/docker-compose.yml`](../db/docker-compose.yml))

## Puesta en marcha (3 comandos)

```bash
# 1. Base de datos (desde ../db)
cd ../db && docker compose up -d

# 2. API
cd ../pethouse-api
cp .env.example .env        # ajusta DATABASE_URL si es necesario
npm install
npm start                   # → http://localhost:3001
```

Probar: `curl http://localhost:3001/health`

## Módulos y rutas

| Módulo | Rutas | Auth |
|---|---|---|
| **Auth** | `POST /api/auth/registro` · `POST /api/auth/login` · `POST /api/auth/refresh` · `POST /api/auth/logout` · `GET /api/auth/me` · `PATCH /api/auth/me` | login/editar → JWT |
| **Hospedajes** | `GET /api/hospedajes` (filtros + radio) · `GET /api/hospedajes/cerca` · `GET /api/hospedajes/mios` · `GET /api/hospedajes/:id` · `GET /api/hospedajes/:id/reservas` · `POST /api/hospedajes` | crear/mios/reservas: anfitrión |
| **Reservas** | `POST /api/reservas` · `GET /api/reservas/mias` · `GET /api/reservas/:id` · `POST /api/reservas/:id/cancelar` · `POST /api/reservas/:id/plan` | ✅ |
| **Actividades** | `GET /api/actividades?tipo=` · `POST /api/actividades` | crear: anfitrión |
| **Reseñas** | `POST /api/hospedajes/:id/resenas` | ✅ (una por reserva) |
| **Chat** | `GET /api/conversaciones` · `POST /api/conversaciones` · `GET/POST /api/conversaciones/:id/mensajes` · `POST /api/conversaciones/:id/leidas` | ✅ |
| **Mascotas** | `POST /api/mascotas` · `PATCH /api/mascotas/:id` · `DELETE /api/mascotas/:id` | ✅ (dueño de la mascota) |
| **Favoritos** | `GET /api/favoritos` · `POST /api/favoritos` · `DELETE /api/favoritos/:hospedajeId` | ✅ |
| **Subidas** | `POST /api/subidas` (multipart, campo `archivo`, imagen o PDF) → `201 { url }`, servido desde `/uploads` | ✅ |
| **Verificación anfitrión** | `POST/GET /api/anfitrion/verificacion` (nombre legal, cédula, certificado policial, referencias, fotos) — enviarla activa `usuarios.es_anfitrion` | ✅ |
| **Preferencias anfitrión** | `POST/GET /api/anfitrion/preferencias` (especies, modalidades días/horas, tamaños) | ✅ |
| **IA** | `GET /api/ia/estado` · `POST /api/ia` (proxy Gemini, clave en `.env`) | pública (con rate limit) |

Los módulos de Mascotas, Favoritos y Subidas, más `GET /api/hospedajes/mios`, `GET /api/hospedajes/:id/reservas`
y `PATCH /api/auth/me`, se agregaron para cerrar los gaps documentados en
[`../ARCHITECTURE_AUDIT.md`](../ARCHITECTURE_AUDIT.md) — el cliente iOS (`../PetHouseiOS/`) ya
los consume, dejaron de responder 404 de "ruta no implementada".

### Búsqueda con filtros (igual que el buscador de la app)

```
GET /api/hospedajes?ciudad=Bogotá&tipo=guarderia&convivencia=compartida
                   &desde=2026-12-01&hasta=2026-12-05
                   &lat=4.711&lng=-74.072&radio=5000&q=guardería&orden=precio-asc
```

- `lat+lng+radio` → búsqueda espacial con **índice GIST** (PostGIS).
- `desde+hasta` → solo hospedajes sin reservas confirmadas solapadas.
- `q` → búsqueda de texto (`to_tsvector` español).

## Seguridad implementada

- Contraseñas con **bcrypt** (nunca en claro).
- **JWT**: access 15 min + refresh token rotativo almacenado en `sesiones`.
- SQL 100% parametrizado (sin inyección).
- **Anti-doble-reserva**: transacción con `FOR UPDATE` + restricción EXCLUDE en la BD → 409.
- La clave de Gemini solo vive en el servidor (`GEMINI_API_KEY`).
- **`JWT_SECRET` obligatorio en producción**: el servidor no arranca si falta y
  `NODE_ENV=production`. En desarrollo se genera uno aleatorio por ejecución si no se
  configura (ver `src/config.js`) — nunca hay un secreto público conocido.
- **CORS restringido** vía `ALLOWED_ORIGINS` (lista separada por coma). Sin configurar
  queda abierto, solo aceptable en desarrollo.
- **Rate limiting**: `/api/auth/*` (20 intentos/15min por IP) y `/api/ia` (30/15min por IP),
  ver `src/middleware/rateLimit.js`.
- **`usuarios.es_anfitrion` solo se activa completando la verificación de seguridad**
  (`POST /api/anfitrion/verificacion`) — no existe ningún atajo/endpoint que lo active
  directo. Datos sensibles (cédula, certificado de antecedentes) quedan en
  `verificaciones_anfitrion` con estado `pendiente` (no hay panel de revisión todavía en
  este MVP, ver `db/06-verificacion-anfitrion.sql`). **Antes de manejar estos datos en
  producción real, revisar cumplimiento de la Ley 1581 de 2012 (protección de datos
  personales en Colombia)** — cifrado en reposo, política de privacidad, retención, etc.
  no están cubiertos por este MVP.

## Probar la API (test de integración)

```bash
bash test-api.sh        # 15 verificaciones contra la API real
```

## Desplegar

Render / Railway / ECS (ver Dockerfile):

```bash
docker build -t pethouse-api .
docker run -p 3001:3001 --env-file .env pethouse-api
```

Variables de entorno: `PORT`, `DATABASE_URL`, `JWT_SECRET`, `GEMINI_API_KEY`, `GEMINI_MODEL`, `PGSSLMODE=require` (bases en la nube tipo Neon/Supabase).

## Roadmap

- WebSockets para el chat en tiempo real (hoy: REST + polling).
- Pasarela de pagos (Wompi/PayU): el endpoint de reserva ya crea el pago `pendiente`.
- Notificaciones push/correo vía worker (BullMQ).
