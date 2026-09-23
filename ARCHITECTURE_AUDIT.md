# 🔍 ARCHITECTURE_AUDIT.md — Auditoría del repositorio PetHouse

> Generado para planear el MVP nativo de iOS. Cubre lo que ya existe (backend, datos,
> diseño, convenciones) y lo que falta para soportar una app iOS real.

---

## 1. Qué hay en el repo hoy (tres capas, distinto nivel de madurez)

```
PetHouse/
├── index.html + part1-4_*.html + _src/   → App web autocontenida (HTML/CSS/JS vanilla,
│                                            imágenes en base64, sin build). ES EL PROTOTIPO
│                                            de referencia visual y funcional.
├── pethouse-api/                          → API REST real (Node/Express + PostgreSQL/PostGIS)
├── db/                                    → Esquema SQL, seed, docker-compose (Postgres+PostGIS)
├── docs/ARQUITECTURA.md, DIAGRAMA-ER.html → Documento de arquitectura (C4 + ADR) y diagrama ER
├── pethouse-ios/                          → Envoltorio Capacitor (WebView) del index.html,
│                                            proyecto Xcode ya generado — NO es código Swift real
├── GUIA-IOS.md, PLAN-XCODE.md             → Guías para compilar el wrapper Capacitor
└── manifest.webmanifest, sw.js, icon-*    → PWA (instalación sin App Store)
```

**Punto clave:** el `index.html` (el "producto" que hoy usa la gente) **no consume la API
real**. Usa datos de ejemplo hardcodeados en JS + `localStorage`. La API PostGIS se construyó
en paralelo y está probada de forma independiente (`test-api.sh`, 15/15 checks), pero nada la
conecta todavía al frontend. Para el MVP de iOS, la API es la única pieza reutilizable a nivel
de lógica de negocio — el HTML solo sirve como **referencia de diseño y de flujos de UX**.

---

## 2. Backend existente

- **Framework:** Node.js (ESM) + Express 4, arquitectura de **monolito modular**: 7 módulos de
  rutas montados sobre un único `app.js` (`pethouse-api/src/app.js`).
- **Base de datos:** PostgreSQL 14+ con PostGIS (geolocalización), `citext` (emails
  case-insensitive), `pg_trgm` y `btree_gist` (para la restricción anti-doble-reserva).
  Se levanta con `db/docker-compose.yml`.
- **Autenticación:** JWT de acceso (15 min) + refresh token opaco rotativo, guardado en la
  tabla `sesiones` (revocable, ligado a `user_agent`). Contraseñas con **bcrypt**.
- **Errores:** manejador centralizado que traduce códigos de Postgres a HTTP
  (23P01/23505→409 conflicto, 23503→400 referencia inválida, 23514→400 fuera de rango).

### 2.1 Endpoints existentes (contrato real, no el propuesto en ARQUITECTURA.md)

| Módulo | Método y ruta | Auth | Notas |
|---|---|---|---|
| Auth | `POST /api/auth/registro` | — | Crea usuario (rol `cliente`/`anfitrion`) + 1 mascota opcional |
| Auth | `POST /api/auth/login` | — | Devuelve `{ usuario, accessToken, refreshToken, expiraEn }` |
| Auth | `POST /api/auth/refresh` | refresh | Rota el refresh token |
| Auth | `POST /api/auth/logout` | refresh | Revoca el refresh token |
| Auth | `GET /api/auth/me` | ✅ | Usuario + sus mascotas |
| Hospedajes | `GET /api/hospedajes` | — | Filtros: `ciudad, tipo, convivencia, desde, hasta, lat, lng, radio, q, orden`. **`LIMIT 100` fijo, sin paginación** |
| Hospedajes | `GET /api/hospedajes/cerca` | — | Búsqueda por radio (PostGIS `ST_DWithin`) |
| Hospedajes | `GET /api/hospedajes/:id` | — | Detalle + anfitrión + últimas 20 reseñas |
| Hospedajes | `POST /api/hospedajes` | ✅ anfitrión | Crea hospedaje (recibe `fotos` como array de strings — **no hay endpoint de subida**, hay que mandar URLs ya alojadas en otro lado) |
| Reservas | `POST /api/reservas` | ✅ | Transacción con `SELECT...FOR UPDATE` + `EXCLUDE` en BD → 409 si hay solape |
| Reservas | `GET /api/reservas/mias` | ✅ | Reservas del usuario logueado (como dueño) |
| Reservas | `GET /api/reservas/:id` | ✅ | Detalle + plan de actividades (dueño o anfitrión del hospedaje) |
| Reservas | `POST /api/reservas/:id/cancelar` | ✅ | Solo si es del usuario y está `confirmada` |
| Reservas | `POST /api/reservas/:id/plan` | ✅ | Agrega una actividad al plan de la reserva |
| Actividades | `GET /api/actividades` | — | Filtro `tipo`, `q` |
| Actividades | `POST /api/actividades` | ✅ anfitrión | Crea actividad |
| Reseñas | `POST /api/hospedajes/:id/resenas` | ✅ | Una por reserva; valida pertenencia; trigger SQL recalcula rating |
| Chat | `GET/POST /api/conversaciones` | ✅ | Listar / crear-u-obtener conversación |
| Chat | `GET/POST /api/conversaciones/:id/mensajes` | ✅ | Polling, no WebSockets |
| Chat | `POST /api/conversaciones/:id/leidas` | ✅ | Marca mensajes como leídos |
| IA | `GET /api/ia/estado`, `POST /api/ia` | — | Proxy a Gemini, clave solo en servidor |
| — | `GET /health` | — | Healthcheck |

**No existen** (aunque el prototipo HTML sí los simula en el frontend con datos falsos):
`PATCH` de perfil de usuario, CRUD de mascotas más allá del registro, endpoints de favoritos
(la tabla existe, la ruta no), listado de hospedajes/reservas *del anfitrión*, edición/borrado
de hospedajes, recuperación de contraseña, verificación de email, ni ningún endpoint de subida
de archivos.

---

## 3. Modelos de datos (13 tablas, `db/01-esquema.sql`)

```
usuarios (id, nombre, email, telefono, password_hash, rol[cliente|anfitrion|admin], verificado)
 └─ mascotas (usuario_id, nombre, especie, raza, peso_kg, vacunas_dia, notas)
 └─ hospedajes (anfitrion_id, tipo[guarderia|veterinaria|campestre|apartamento|domicilio],
                titulo, descripcion, ciudad, barrio, ubicacion GEOGRAPHY(POINT,4326),
                cobertura_radio_m, precio_noche, convivencia, max_mascotas, rating,
                num_resenas, servicios[], reglas[], fotos[], activo)
     ├─ actividades (tipo[paseos|piscina|entrenamiento|spa|fotos|social], precio)
     ├─ resenas (reserva_id UNIQUE, rating 1-5, titulo, texto) → trigger recalcula rating
     └─ reservas (usuario_id, hospedaje_id, desde, hasta, noches GENERATED, mascotas,
                  precio_noche, limpieza, servicio, total GENERATED, estado)
           ├─ plan_actividades (reserva_id, actividad_id, fecha, precio)
           └─ pagos (reserva_id UNIQUE, monto, metodo, estado[pendiente|aprobado|rechazado|reembolsado])
 └─ conversaciones (usuario_id, anfitrion_id, hospedaje_id) → mensajes (texto, leido)
 └─ favoritos (usuario_id, hospedaje_id) — sin endpoints todavía
 └─ sesiones (refresh_token, user_agent, expira_en) — sin soporte para push tokens
auditoria (tabla, operacion, registro_id, datos jsonb) — opcional, no usada por la API hoy
```

Todos los IDs son `UUID`. `noches` y `total` en `reservas` son columnas **generadas**
(cero riesgo de desincronización cliente/servidor en el precio). El anti-doble-reserva usa
`EXCLUDE USING gist (hospedaje_id WITH =, daterange(desde,hasta) WITH &&)`, reforzado con
`FOR UPDATE` en la transacción — robusto ante condiciones de carrera.

---

## 4. Diseño / marca existente

No hay Figma, wireframes ni archivos de diseño separados — el **sistema de diseño vive como
código** dentro de `part1_head.html` (CSS custom properties), documentado como "Material
Design 3 + brief" en el propio archivo:

| Token | Valor | Uso |
|---|---|---|
| `--ph-primary` | `#FB3F57` (coral) | Color de marca, botones primarios, `theme-color` del manifest |
| `--ph-primary-hover` / `--ph-primary-active` | `#E5324A` / `#CF2A40` | Estados interactivos |
| `--ph-primary-container` / `--ph-on-primary-container` | `#FFDEE3` / `#4B0E1A` | Fondos suaves de marca |
| `--ph-ink` | `#2A2F35` | Texto principal / tinta |
| `--ph-body` / `--ph-muted` / `--ph-muted-soft` | `#3F3F3F` / `#6A6A6A` / `#929292` | Jerarquía de texto secundario |
| `--ph-canvas` / `--ph-surface-soft` / `--ph-surface-strong` | `#fff` / `#F7F7F7` / `#F2F2F2` | Fondos |
| `--ph-hairline` / `--ph-hairline-soft` | `#DDDDDD` / `#EBEBEB` | Bordes |
| `--ph-error` / `--ph-error-container` | `#C13515` / `#FFDAD2` | Estados de error |
| `--ph-success` / `--ph-success-container` | `#1A7F4E` / `#D7F1E3` | Estados de éxito |
| Radios | `--ph-r-xs:4px …--ph-r-xl:28px`, `--ph-r-full:9999px` | Esquinas |
| Espaciado | `--ph-s-4` … `--ph-s-64` (escala de 4/8) | Padding/gap |
| Sombras | 3 niveles (`shadow-1/2/3`), sutiles, tipo Material | Elevación de cards/modales |
| Tipografía | `'Airbnb Cereal VF', Circular, -apple-system…` | **Fuente propietaria de Airbnb** — no se puede usar tal cual en la app iOS, hay que sustituirla (ver §6) |
| Tipos de texto | `.d-xl/lg/md/sm` (display), `.t-md`, `.b-md/sm` (body), `.cap-sm`, `.micro` | Escala tipográfica ya definida (tamaño/peso/line-height) |

**No hay modo oscuro** definido en el CSS actual (todo es sobre `--ph-canvas:#fff`) — el modo
oscuro para iOS habría que diseñarlo desde cero, no adaptarlo.

**Assets ya generados:** `apple-touch-icon.png` (180px), `icon-192.png`, `icon-512.png`
(huella coral sobre fondo `#FB3F57`) — reutilizables como base del ícono de la app nativa.
También existe un mapa SVG de Colombia embebido (`colombia.geo.json`/`col.json`) usado por la
vista `#/mapa` del prototipo — para iOS lo natural es reemplazarlo por MapKit nativo en vez de
portar el SVG.

**Envoltorio iOS ya existente:** `pethouse-ios/` es un proyecto **Capacitor** (WebView, no
Swift real) con `appId: co.pethouse.app`, `appName: Pethouse`. Es la "Opción B" descrita en
`GUIA-IOS.md`. **Este audit es el punto de partida para reemplazarlo por una app SwiftUI
nativa de verdad** — el proyecto Capacitor puede quedar como referencia de bundle ID / nombre
pero no se reutiliza código de él.

---

## 5. Convenciones ya establecidas (a respetar o decidir explícitamente romper)

- **Idioma del dominio:** rutas, campos JSON y mensajes de error están en **español**
  (`hospedaje`, `anfitrion`, `desde/hasta`, `precio_noche`, `mascotas`, errores como
  `"Ingresa tu correo y contraseña."`). Los DTOs de la app iOS deberían mapear 1:1 estos
  nombres (o definir una capa de traducción explícita en la capa de Networking) para no
  arrastrar dos vocabularios distintos en el código Swift.
- **IDs:** UUID string en todas las entidades (no enteros incrementales).
- **Fechas:** `DATE` (`YYYY-MM-DD`) para `desde/hasta` de reservas, `TIMESTAMPTZ` ISO 8601 para
  `creado_en`.
- **Errores:** siempre `{ "error": "mensaje en español, legible para el usuario" }` — se puede
  mostrar directo en UI sin re-mapear códigos, pero no hay un campo `code` machine-readable
  aparte del status HTTP.
- **Paginación:** ausente. Todo listado es `LIMIT` fijo sin cursor/página.
- **Sin versión de API** (`/api/...`, no `/api/v1/...`) — importante decidir ahora si el
  cliente iOS fija headers o tolera cambios breaking sin aviso.

---

## 6. Gaps para soportar un MVP de iOS (bloqueantes vs. no bloqueantes)

### 🔴 Bloqueantes (sin esto, funcionalidades completas del MVP no pueden implementarse)

1. **Subida de imágenes:** no existe endpoint de upload ni storage configurado (S3/Cloudinary
   solo se *sugieren* en `docs/ARQUITECTURA.md` como roadmap). Sin esto, un anfitrión no puede
   publicar un hospedaje con fotos reales desde el teléfono, y un dueño no puede poner foto de
   perfil/mascota.
2. **`JWT_SECRET` con fallback inseguro en código** (`pethouse-api/src/config.js:8`):
   si se despliega sin `.env`, firma tokens con un secreto público conocido. Hay que hacer que
   el servidor **falle al arrancar** si falta la variable, antes de exponer la API a una app
   real en producción.
3. **CORS abierto sin restricción** (`cors()` sin opciones) y **sin rate limiting** en
   `/api/auth/login` ni `/api/ia` — necesario acotar antes de publicar la app.

### 🟡 Necesarios para el alcance típico de un MVP (se pueden priorizar en el Paso 2)

4. **Paginación** en `GET /api/hospedajes` (hoy `LIMIT 100` fijo) — sin esto, listas largas en
   iOS no pueden paginar/hacer scroll infinito correctamente.
5. **Editar perfil de usuario** (`PATCH /api/auth/me` no existe) y **CRUD completo de
   mascotas** (hoy solo se crea 1 mascota durante el registro; no hay `POST/PATCH/DELETE
   /api/mascotas`).
6. **Vista de anfitrión:** no hay `GET /api/hospedajes/mios` ni forma de listar las reservas
   *recibidas* en los hospedajes propios — solo `GET /api/reservas/mias` (como dueño/cliente).
7. **Favoritos:** la tabla existe pero no hay rutas (`GET/POST/DELETE /api/favoritos`).
8. **Notificaciones push:** no hay tabla de device tokens ni integración APNs/FCM (roadmap en
   `docs/ARQUITECTURA.md` lo marca "⏳"). Se necesita como mínimo una tabla
   `push_tokens (usuario_id, token, plataforma)` y un endpoint para registrarlo; el envío real
   (APNs) es trabajo adicional de infraestructura.
9. **Pagos:** por decisión de arquitectura ya tomada (**ADR-7**: "pagos en fase 2"), hoy una
   reserva se confirma **sin cobro real** — solo se crea un registro `pagos` en estado
   `pendiente`. Cualquier flujo de "pago" en el MVP de iOS debe ser honesto sobre esto (o
   integrarse una pasarela en modo sandbox, lo cual es trabajo de backend nuevo).
10. **Recuperación de contraseña** y **verificación de email**: no implementadas (`verificado`
    existe en la tabla pero nada lo actualiza).

### 🟢 No bloqueantes / decisiones de producto, no de datos

- **Chat en tiempo real:** hoy es REST + polling (documentado como decisión temporal en
  `pethouse-api/README.md`, WebSockets están en el roadmap). Es viable para un MVP con polling
  cada pocos segundos; no bloquea el lanzamiento.
- **Mapa:** el prototipo usa un SVG propio; para iOS lo natural es MapKit, que no depende de
  ningún cambio de backend (la API ya devuelve `lat/lng`).
- **Sin CI/CD:** el workflow de GitHub Actions fue removido (commit `e3c5692`, "pendiente
  scope workflow en el token"). No bloquea el desarrollo de la app, pero sí la entrega
  continua a TestFlight si se quisiera automatizar luego.
- **Despliegue de la API:** no hay evidencia de que la API esté corriendo en un servidor
  público hoy (solo instrucciones para Render/Railway/Neon en el README) — para desarrollar la
  app iOS contra datos reales, primero hay que desplegarla en algún entorno accesible (o
  correrla localmente apuntando el simulador a `http://localhost:3001`).

---

## 7. Conclusión de la auditoría

El backend (API + base de datos PostGIS) es sólido en lo que ya cubre: auth, búsqueda
espacial/textual, reservas sin condiciones de carrera, reseñas con trigger de rating, y chat
básico. El sistema de diseño está bien definido como tokens reutilizables. Pero para un MVP de
iOS completo (con fotos, notificaciones, perfil editable, vista de anfitrión y favoritos) hace
falta trabajo de backend **en paralelo** al desarrollo de la app — no es solo "conectar" un
cliente Swift a lo que ya existe.

→ Ver `MVP_SCOPE.md` para la propuesta de alcance mínimo viable y qué se hace en cada frente.
