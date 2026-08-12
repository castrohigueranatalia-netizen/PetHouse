# 🎯 MVP_SCOPE.md — Alcance propuesto para el MVP de iOS

> Basado en `ARCHITECTURE_AUDIT.md`. Cada funcionalidad se marca según lo que el backend
> soporta **hoy**, no lo que es técnicamente posible en el futuro.

Leyenda: ✅ backend listo · 🟡 backend parcial (falta algo puntual) · 🔴 pendiente backend

> **Actualización posterior al MVP inicial:** los 6 gaps 🔴 de la tabla (#3 editar perfil,
> #4 CRUD mascotas, #11→pagos se mantiene sin cambios, #14 favoritos, #16/#17 vista de
> anfitrión) y el gap bloqueante de subida de imágenes se cerraron implementando el backend
> propuesto (`PATCH /api/auth/me`, `POST/PATCH/DELETE /api/mascotas`,
> `GET/POST/DELETE /api/favoritos`, `GET /api/hospedajes/mios`,
> `GET /api/hospedajes/:id/reservas`, `POST /api/subidas`), además del hardening de
> seguridad bloqueante (`JWT_SECRET` obligatorio en producción, CORS restringido, rate
> limiting). El cliente iOS ya estaba escrito contra ese contrato — empezó a funcionar sin
> tocar Swift. Ver `pethouse-api/README.md` para el detalle de rutas y variables de entorno
> nuevas. La paginación de `GET /api/hospedajes` (#7) también se cerró: `pagina`/`porPagina`
> reales contra la base (`COUNT(*) OVER()` + `LIMIT/OFFSET`) en vez del `LIMIT 100` fijo que
> el cliente completaba con paginación local — `BuscarViewModel` ahora pide páginas nuevas
> de verdad al hacer scroll.

---

## 1. Alcance funcional propuesto

| # | Funcionalidad | Estado backend | Incluir en MVP v1 | Nota |
|---|---|---|---|---|
| 1 | Registro / login (dueño y anfitrión) | ✅ | Sí | JWT access+refresh ya funcional |
| 2 | Ver perfil propio + mascotas | ✅ (`GET /me`) | Sí | |
| 3 | Editar perfil (nombre, teléfono, foto) | 🔴 (no hay `PATCH`, no hay upload) | Sí, versión mínima | Requiere 2 endpoints nuevos: `PATCH /api/auth/me` + subida de imagen |
| 4 | CRUD de mascotas (agregar/editar/eliminar más de una) | 🔴 (solo se crea 1 al registrarse) | Sí, versión mínima | Requiere `POST/PATCH/DELETE /api/mascotas` |
| 5 | Búsqueda y listado (ciudad, tipo, fechas, convivencia, texto) | ✅ | Sí | Ya soporta todos los filtros del prototipo HTML |
| 6 | Búsqueda por cercanía / mapa | ✅ (`/cerca`, `lat/lng/radio`) | Sí | En iOS: MapKit nativo, no el SVG del prototipo |
| 7 | Paginación / scroll infinito en resultados | ✅ (`pagina`/`porPagina` reales) | Sí | Cerrado — ver nota de actualización arriba |
| 8 | Detalle de hospedaje (fotos, servicios, reglas, host, reseñas) | ✅ | Sí | |
| 9 | Flujo de reserva (solicitud → confirmación) | ✅ (sin cobro real, ver #11) | Sí | Transacción anti-doble-reserva ya robusta |
| 10 | Mis reservas (ver, cancelar) | ✅ | Sí | |
| 11 | Pago | 🔴 (tabla `pagos` en estado `pendiente` únicamente, **ADR-7 lo difiere a fase 2 a propósito**) | **Depende de tu decisión** (ver §3) | No hay pasarela integrada hoy |
| 12 | Reseñas post-servicio | ✅ | Sí | Una por reserva, ya validada server-side |
| 13 | Chat dueño ⇄ anfitrión | ✅ (REST + polling, no WebSockets) | Sí, con polling | Suficiente para MVP; tiempo real queda para v1.1 |
| 14 | Favoritos | 🔴 (tabla existe, sin rutas) | Sí, versión mínima | Requiere 3 endpoints nuevos, es trabajo chico |
| 15 | Notificaciones push (confirmaciones, mensajes) | 🔴 (sin tabla de device tokens ni envío APNs) | **Depende de tu decisión** (ver §3) | Es la pieza de infraestructura más grande de las pendientes |
| 16 | Vista de anfitrión: publicar hospedaje | ✅ (`POST /api/hospedajes`) pero sin subida de fotos | Sí, versión mínima | Sin endpoint de imágenes, el anfitrión tendría que pegar URLs — no viable para un MVP real, así que depende de #3/subida de imágenes |
| 17 | Vista de anfitrión: ver reservas recibidas / mis hospedajes | 🔴 (no existe endpoint) | Sí, versión mínima | Requiere `GET /api/hospedajes/mios` y forma de listar reservas por anfitrión |
| 18 | Recuperar contraseña | 🔴 | **No** (fuera del MVP) | Se puede lanzar v1 sin esto; agregar en v1.1 |
| 19 | Verificación de email | 🔴 | **No** (fuera del MVP) | Igual, v1.1 |
| 20 | Asistente de IA "Dr. Pethouse" | ✅ (proxy a Gemini) | Opcional / nice-to-have | Ya funciona end-to-end en el prototipo, portar es directo |

---

## 2. Qué NO entra en el MVP v1 (explícito, para evitar scope creep)

- Pagos reales con pasarela (PSE/tarjetas) — se lanza con "reserva confirmada, pago se coordina
  aparte" salvo que decidas lo contrario (ver §3).
- Chat en tiempo real con WebSockets (queda en polling).
- Recuperación de contraseña / verificación de email.
- Moderación, panel de administración, reportes.
- Multi-idioma (todo queda en español, igual que el backend).
- Publicación de hospedaje con flujo completo de anfitrión "avanzado" (edición posterior,
  pausar/reactivar, estadísticas) — solo publicar + ver lo publicado.

---

## 3. Decisiones confirmadas (2026-08-09)

**A. Notificaciones push → Opción 1, sin push del servidor en v1.** El MVP se lanza solo con
notificaciones locales del dispositivo (si aplica, ej. recordatorio de check-in), sin depender
de backend. Push real (confirmaciones de reserva, mensajes nuevos) queda para v1.1, cuando se
agregue la tabla de device tokens y la integración APNs.

**B. Pagos → se mantiene el ADR-7.** La reserva se confirma sin cobro real, igual que hoy en la
API. La UI de iOS debe ser explícita al respecto (p. ej. "Reserva confirmada — el pago se
coordina directamente con el anfitrión"). Cero trabajo de backend nuevo para pagos en el MVP.

**C. Alcance funcional → aprobado.** Se avanza con: registro/login, búsqueda + mapa nativo
(MapKit), detalle de hospedaje, flujo de reserva, mis reservas, chat por polling, reseñas,
favoritos, perfil editable, CRUD de mascotas y vista básica de anfitrión — **todas las
funcionalidades marcadas 🔴 en la tabla del §1 se implementan del lado de iOS con su capa de
servicio ya definida contra el contrato de API que tendría el backend, pero mostrando un
estado "función pendiente en el servidor" en vez de simularla como exitosa**, ya que no se
modifica `pethouse-api/` en esta fase (eso queda para cuando se decida ampliar el backend).

---

## 4. Resumen del trabajo de backend que este alcance implica (en paralelo al desarrollo iOS)

Aunque tú construyas la app en Swift, alguien tiene que ampliar `pethouse-api/` con:

1. `PATCH /api/auth/me` (editar perfil) + `POST/PATCH/DELETE /api/mascotas`.
2. Endpoint de subida de imágenes (perfil, mascota, hospedaje) + storage (S3/Cloudinary) —
   bloqueante para #3, #16 de la tabla de arriba.
3. Paginación en `GET /api/hospedajes`.
4. `GET /api/hospedajes/mios` + endpoint de reservas recibidas por anfitrión.
5. `GET/POST/DELETE /api/favoritos`.
6. Endurecer seguridad: `JWT_SECRET` obligatorio (fail-fast), CORS restringido a los orígenes
   reales, rate limiting en `/api/auth/*` y `/api/ia`.
7. (Solo si eliges Opción 2 en push) tabla de device tokens + servicio de envío.

Esto se puede hacer en Node/Express siguiendo exactamente las convenciones ya establecidas
(mismo estilo de módulos, mismo manejador de errores, mismo idioma de campos) — no es una
reescritura, es extender lo existente.

---

## 5. Siguiente paso

Con tu aprobación (o ajustes) de este alcance y las dos decisiones de §3, paso al **Paso 3**:
arquitectura técnica de la app iOS (SwiftUI + MVVM + estructura de carpetas modular) y arranco
la implementación del MVP — incluyendo, si así lo apruebas, los cambios de backend necesarios
para soportarlo.
