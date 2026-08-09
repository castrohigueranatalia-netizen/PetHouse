# PetHouse iOS (MVP nativo, SwiftUI)

App nativa de iOS para PetHouse (hospedaje de mascotas), construida desde cero en SwiftUI
+ Swift Concurrency, a partir de la auditoría en [`../ARCHITECTURE_AUDIT.md`](../ARCHITECTURE_AUDIT.md)
y el alcance aprobado en [`../MVP_SCOPE.md`](../MVP_SCOPE.md). No reutiliza código de
`../pethouse-ios/` (wrapper Capacitor/WebView) ni toca `../pethouse-api/`, `../db/` o el
prototipo HTML — es trabajo puramente aditivo en esta carpeta.

Este proyecto se escribió **sin acceso a Xcode/macOS**. No se compiló ni se abrió en
Xcode durante el desarrollo — revísalo con cuidado la primera vez que lo abras en una Mac.

---

## Cómo correr el proyecto

### Requisitos

- macOS con Xcode 15+ (Swift 5.10, SDK de iOS 17+).
- [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
- `pethouse-api` corriendo localmente (ver `../pethouse-api/README.md`): típicamente
  `docker compose up -d` en `../db/` para Postgres/PostGIS, y luego `npm install && npm start`
  dentro de `../pethouse-api/` (por defecto queda en `http://localhost:3001`).

### Generar y abrir el proyecto Xcode

Este repo **no** incluye un `.xcodeproj` a mano (evita el riesgo de un `project.pbxproj`
corrupto escrito sin poder abrirlo en Xcode). En su lugar, `project.yml` describe el
target completo y XcodeGen genera el `.xcodeproj` real:

```bash
cd PetHouseiOS
xcodegen generate
open PetHouseiOS.xcodeproj
```

Corre el esquema `PetHouseiOS` en un simulador de iOS 17+. Vuelve a correr
`xcodegen generate` cada vez que cambies `project.yml` (nuevos archivos sueltos también
se recogen automáticamente porque las fuentes se referencian por carpeta, no archivo por
archivo).

### Apuntar la app a un backend distinto de `localhost:3001`

La URL base se lee en runtime desde Info.plist (`API_BASE_URL`, ver
`Networking/APIConfig.swift`), que a su vez toma el build setting `API_BASE_URL` definido
en `project.yml` (`settings.base.API_BASE_URL`). Para apuntar a un backend desplegado:

1. Edita `API_BASE_URL` en `project.yml` (o mejor, crea un `.xcconfig` por configuración
   Debug/Release si vas a manejar varios entornos) y corre `xcodegen generate` de nuevo.
2. Si el backend nuevo sirve por HTTPS, puedes quitar la excepción de
   `NSAppTransportSecurity` para `localhost` que hoy permite HTTP sin TLS solo en
   desarrollo local (ver comentario en `project.yml`).

### Simulador vs. dispositivo físico

`http://localhost:3001` funciona tal cual en el Simulador de iOS (comparte el loopback de
red de la Mac). Para probar en un iPhone físico contra la API corriendo en tu Mac, usa la
IP local de tu Mac en la red Wi-Fi (ej. `http://192.168.1.23:3001`) en vez de `localhost`.

---

## Qué endpoints son reales hoy vs. cuáles esperan un backend que aún no existe

Ver el detalle completo y el porqué de cada gap en
[`../ARCHITECTURE_AUDIT.md`](../ARCHITECTURE_AUDIT.md) §2 y
[`../MVP_SCOPE.md`](../MVP_SCOPE.md) §1/§4. Resumen desde el punto de vista del cliente:

### ✅ Funciona contra `pethouse-api` tal como existe hoy

| Feature | Service | Endpoints reales |
|---|---|---|
| Login / registro / sesión | `AuthService` | `POST /api/auth/{registro,login,refresh,logout}`, `GET /api/auth/me` |
| Buscar + mapa | `HospedajesService` | `GET /api/hospedajes`, `GET /api/hospedajes/cerca`, `GET /api/hospedajes/:id` |
| Publicar hospedaje | `HospedajesService.crear` | `POST /api/hospedajes` (fotos como URLs ya alojadas — ver abajo) |
| Reservar / mis reservas / cancelar | `ReservasService` | `POST /api/reservas`, `GET /api/reservas/mias`, `GET /api/reservas/:id`, `POST /api/reservas/:id/cancelar` |
| Reseñas | `ResenasService` | `POST /api/hospedajes/:id/resenas` |
| Chat (con polling ~5s) | `ChatService` | `GET/POST /api/conversaciones`, `GET/POST /api/conversaciones/:id/mensajes`, `POST .../leidas` |
| Actividades | `ActividadesService` | `GET /api/actividades` |

### 🔴 Implementado en el cliente (UI + ViewModel + Service) contra un contrato PROPUESTO — el backend responde 404 hoy

Cada `Service` de esta lista tiene, en su propio archivo, el contrato de ruta/payload
propuesto (nombre exacto, método, forma del JSON) siguiendo las convenciones ya vigentes
en `pethouse-api`. Cuando esas rutas existan en el servidor, el cliente empieza a
funcionar sin cambios — no hay nada que "activar".

| Feature | Service | Ruta propuesta |
|---|---|---|
| Editar perfil | `PerfilService` | `PATCH /api/auth/me` |
| CRUD de mascotas (más allá de la 1 del registro) | `MascotasService` | `POST/PATCH/DELETE /api/mascotas[/:id]` |
| Favoritos | `FavoritosService` | `GET/POST/DELETE /api/favoritos[/:hospedajeId]` |
| Mis hospedajes (anfitrión) | `AnfitrionService.misHospedajes` | `GET /api/hospedajes/mios` |
| Reservas recibidas (anfitrión) | `AnfitrionService.reservasRecibidas` | `GET /api/hospedajes/:id/reservas` |
| Subida de imágenes (perfil, mascota, hospedaje) | `ImagenesService` | `POST /api/subidas` (multipart) |

**Cómo se distingue "función pendiente" de un error real:** el manejador de errores
centralizado de la API (`pethouse-api/src/middleware/middleware.js#noEncontrado`) responde
`404 { "error": "Ruta no encontrada: MÉTODO /ruta" }` para cualquier ruta que no existe.
`Networking/APIClient.swift` detecta exactamente ese formato de mensaje y lo traduce a
`AppError.rutaNoImplementada`, que las vistas muestran como un estado informativo
("Esta función estará disponible pronto", con ícono de reloj) usando
`DesignSystem/Components/PHStateViews.swift` — nunca como un error rojo genérico, y nunca
simulando un éxito falso. Un 404 de "recurso no encontrado" dentro de una ruta que sí
existe (ej. `"Hospedaje no encontrado."`) usa un mensaje distinto y se trata como el error
normal que es.

### Gaps del propio flujo de reservas/reseñas descubiertos al implementar (no solo documentados en el audit)

- `GET /api/reservas/mias` **no incluye `hospedaje_id`** en su SELECT (solo
  `hospedaje_titulo`, `ciudad`, `barrio`, `tipo`, `fotos` vía JOIN) — pero
  `POST /api/hospedajes/:id/resenas` lo necesita en la URL. `NuevaResenaViewModel`
  resuelve esto pidiendo `GET /api/reservas/:id` (que sí trae `rs.*` completo, incluyendo
  `hospedaje_id`) antes de mostrar el formulario de reseña, en vez de asumir que el dato
  ya lo tiene la lista de reservas.
- `POST /api/hospedajes` espera el body en **camelCase** (`precioNoche`, `maxMascotas`,
  `coberturaRadioM`), a diferencia de absolutamente todo el resto de la API, que usa
  snake_case tanto en requests como en responses. `Core/Models/Hospedaje.swift` documenta
  esto en el propio `CrearHospedajeRequest` con su `CodingKeys` dedicado, distinto al de
  `Hospedaje`.
- Las columnas `NUMERIC`/`DECIMAL` de Postgres (`precio_noche`, `rating`, `total`,
  `limpieza`, `servicio`, `peso_kg`) y las que salen de `COUNT(*)`/`ROUND()`
  (`no_leidos`, `distancia_m`) viajan por defecto como **strings** en el JSON con el driver
  `node-postgres` que usa la API, no como números — esto no está documentado en
  `ARCHITECTURE_AUDIT.md` porque es un detalle de serialización del driver, no de la API
  en sí, y no se pudo confirmar 100% sin correr la API real contra Postgres en este
  entorno de desarrollo. Todos los modelos de `Core/Models/` decodifican esos campos de
  forma defensiva (acepta string o number) vía `Core/Utils/FlexibleDecoding.swift` — si
  resulta que en producción SÍ vienen como números, sigue funcionando igual.

---

## Decisiones de arquitectura (resumen)

- **MVVM estricto por capas** (carpetas, no paquetes SPM separados): `DesignSystem` solo
  importa SwiftUI; `Networking` no importa SwiftUI; `Core/Models` no sabe nada de HTTP;
  `Features/*` es lo único que conecta Views, ViewModels y Services.
- **`@Observable` (Observation) en vez de `ObservableObject`/`@Published`**, en todos los
  ViewModels y en `SessionStore` — consistente en todo el proyecto, sin mezclar los dos
  paradigmas.
- **Swift Concurrency puro** (async/await) para toda la capa de red; `APIClient` es un
  `actor` para serializar el refresh de tokens sin locks manuales.
- **SwiftData** solo para caché offline de lectura básica (perfil + mascotas en
  `UsuarioCache`, "mis reservas" en `ReservaCache`) — no hay sincronización bidireccional
  ni resolución de conflictos; si no hay red, se lee lo último cacheado y punto.
- **Keychain, nunca `UserDefaults`**, para `accessToken`/`refreshToken`
  (`Core/Security/KeychainStore.swift`).
- **Cache de imágenes propio** (`DesignSystem/Components/PHCachedAsyncImage.swift`): un
  `NSCache<NSString, UIImage>` en memoria envolviendo una descarga manual por
  `URLSession`, sin Kingfisher/SDWebImage ni ninguna dependencia SPM de terceros — para un
  MVP evita fricción de setup (resolución de paquetes) en un entorno sin red confiable
  para SPM, y NSCache ya cubre el caso de uso real (listas de hospedajes que se recorren
  varias veces). No persiste a disco entre lanzamientos de la app; sería el primer punto a
  mejorar si el consumo de datos importa más adelante.
- **Sin certificate pinning** — decisión consciente, diferida. Un MVP contra un backend
  propio en desarrollo/staging no lo necesita todavía; añadirlo implica gestión de
  rotación de certificados que no vale la pena antes de tener tráfico real en producción.
- **Permisos de iOS pedidos justo antes de usarse**, nunca al abrir la app: ubicación solo
  al tocar "cerca de mí" en Buscar o "usar mi ubicación actual" al publicar un hospedaje
  (`Core/Utils/LocationProvider.swift`); fotos solo al tocar "Elegir foto" en Editar
  perfil (`PhotosPicker`, que además hoy termina en el estado "función pendiente" porque
  no hay endpoint de subida — ver arriba).
- **Sin push del servidor en v1** (decisión de producto ya cerrada, ver
  `../MVP_SCOPE.md` §3.A): no se pide el permiso de notificaciones ni se registra device
  token. Los puntos donde iría ese trabajo en v1.1 están marcados con
  `// TODO v1.1: push`.
- **Sin pagos reales** (ADR-7, ya cerrado): `POST /api/reservas` confirma la reserva sin
  cobro — la API solo crea un registro `pagos` en estado `pendiente`. La UI lo dice
  explícito en la confirmación: *"Reserva confirmada — el pago se coordina directamente
  con el anfitrión."*
- **Favoritos son optimistas y por sesión** (`FavoritosViewModel`): como no hay backend
  todavía, el corazón responde al toque llamando siempre a la ruta real primero, revierte
  si falla, pero no persiste entre reinicios de la app (no hay de dónde leerlo de verdad).

### Decisiones de diseño que no estaban 100% especificadas en el encargo

- **Tipografía:** el CSS original usa `'Airbnb Cereal VF'`, una fuente propietaria de
  Airbnb que no se puede usar en esta app. Se optó por la fuente del sistema (San
  Francisco, vía `Font.system(...)` con `design: .rounded` en los estilos "display") en
  vez de licenciar o empaquetar una tipografía de terceros — gratis, ya optimizada para
  Dynamic Type/VoiceOver, y sin inflar el binario. Ver `DesignSystem/PHTypography.swift`.
- **Paleta de modo oscuro:** el CSS original no define dark mode (todo vive sobre
  `--ph-canvas:#fff`). La paleta oscura en `DesignSystem/PHColor.swift` es una propuesta
  nueva que preserva el ROL semántico de cada token (mismo nombre, mismo uso) con valores
  ajustados a contraste AA sobre fondo oscuro — no es una migración de nada existente.
  Los colores se calculan en código (`Color.dynamic(light:dark:)` en
  `Core/Utils/Color+Hex.swift`) en vez de vivir en un `Assets.xcassets` con color sets,
  porque este proyecto se escribió sin poder abrir Xcode para verificar visualmente un
  catálogo de assets.
- **Token de color `warning`/`warningContainer`:** no existe en el CSS original. Se agregó
  para los estados "función pendiente en el servidor", que necesitaban un tono distinto
  tanto del rojo de error como del verde de éxito.
- **Ícono de la app:** se generó a partir de `../icon-512.png` (huella coral existente),
  escalado a 1024×1024 y aplanado sobre fondo `#FB3F57` (Apple exige el icono de App Store
  sin canal alfa). Es un placeholder razonable, no un diseño final — vale la pena
  reemplazarlo por un ícono diseñado a propósito para el tamaño real antes de publicar.

---

## Estructura de carpetas

```
PetHouseiOS/
├── project.yml              XcodeGen: target, fuentes, Info.plist, permisos, bundle id
├── App/                     @main, RootView (TabView condicional a sesión), SessionStore
├── DesignSystem/            Tokens (color/tipografía/espaciado/radios/sombras) + componentes
├── Core/
│   ├── Models/               structs Codable — contrato exacto de la API (+ propuestos 🔴)
│   ├── Persistence/          @Model de SwiftData (caché offline)
│   ├── Security/              KeychainStore
│   └── Utils/                 AppError, fechas, validación, decodificación defensiva, etc.
├── Networking/
│   ├── APIClient.swift        URLSession + async/await, refresh de tokens, mapeo de errores
│   ├── APIConfig.swift        URL base (Info.plist / build setting)
│   └── Services/               un Service por dominio (ver tabla de endpoints arriba)
└── Features/                  Auth, Search, HospedajeDetail, Reserva, Chat, Resenas,
                                Perfil, Favoritos, Anfitrion — cada una con Views + ViewModels
```

## Qué falta antes de un release real (fuera del alcance de este MVP)

- Los 6 gaps 🔴 de la tabla de arriba, del lado del backend (ver `../MVP_SCOPE.md` §4).
- Tests (unitarios de ViewModels/Services con mocks de los protocolos `*Servicing`, de UI
  de los flujos clave) — no se escribieron en esta pasada por foco de tiempo; la
  arquitectura por protocolos ya está lista para inyectar dobles de prueba.
- Analítica/crash reporting.
- Certificate pinning (ver decisión arriba) y rate limiting del lado del cliente para
  `/auth/login` (hoy solo lo protege el backend, si lo hace).
- Recuperación de contraseña y verificación de email (fuera del MVP v1, ver
  `../MVP_SCOPE.md` §2).
