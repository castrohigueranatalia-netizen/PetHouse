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
| **Auth** | `POST /api/auth/registro` · `POST /api/auth/login` · `POST /api/auth/refresh` · `POST /api/auth/logout` · `GET /api/auth/me` | login → JWT |
| **Hospedajes** | `GET /api/hospedajes` (filtros + radio) · `GET /api/hospedajes/cerca` · `GET /api/hospedajes/:id` · `POST /api/hospedajes` | crear: anfitrión |
| **Reservas** | `POST /api/reservas` · `GET /api/reservas/mias` · `GET /api/reservas/:id` · `POST /api/reservas/:id/cancelar` · `POST /api/reservas/:id/plan` | ✅ |
| **Actividades** | `GET /api/actividades?tipo=` · `POST /api/actividades` | crear: anfitrión |
| **Reseñas** | `POST /api/hospedajes/:id/resenas` | ✅ (una por reserva) |
| **Chat** | `GET /api/conversaciones` · `POST /api/conversaciones` · `GET/POST /api/conversaciones/:id/mensajes` · `POST /api/conversaciones/:id/leidas` | ✅ |
| **IA** | `GET /api/ia/estado` · `POST /api/ia` (proxy Gemini, clave en `.env`) | pública |

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
