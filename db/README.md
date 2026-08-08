# 🗄️ Pethouse · Base de datos PostgreSQL + PostGIS

Modelo de datos completo para la plataforma. Incluye **geolocalización real** con PostGIS
(el mapa de hospedajes y la búsqueda "cuidadores cerca de mí" se resuelven con índices GIST).

## Archivos

| Archivo | Contenido |
|---|---|
| `01-esquema.sql` | Estructura completa: extensiones, enums, 13 tablas, índices (GIST/GIN), triggers, vistas y funciones |
| `02-seed.sql` | Datos demo: 7 usuarios, 2 mascotas, **18 hospedajes con coordenadas reales**, 6 actividades, reseñas |
| `03-consultas.sql` | Consultas de ejemplo: radio de distancia, disponibilidad por fechas, búsqueda combinada, reportes |
| `docker-compose.yml` | Levanta la base local con Docker (PostGIS 16) y ejecuta esquema+seed automáticamente |

## Cómo levantar la base (2 minutos)

```bash
cd db
docker compose up -d        # descarga postgis/postgis:16 y crea la base con datos
psql "postgres://pethouse:pethouse@localhost:5432/pethouse" -c "SELECT postgis_version();"
```

Sin Docker: ejecuta los `.sql` en cualquier PostgreSQL 14+ con la extensión PostGIS instalada.

## El mapa del modelo (resumen)

```
usuarios (cliente | anfitrion | admin)
   ├── mascotas (perros/gatos de los clientes)
   ├── hospedajes ──(PostGIS: ubicacion GEOGRAPHY(POINT,4326))── anfitrión
   │     ├── cobertura_radio_m  → cuidadores a domicilio
   │     ├── actividades (globales o por hospedaje)
   │     ├── resenas (trigger → rating/num_resenas)
   │     └── reservas (rangos de fecha + EXCLUDE anti-traslape)
   │            ├── plan_actividades
   │            └── pagos
   ├── conversaciones ── mensajes (chat interno)
   ├── favoritos
   └── sesiones (refresh tokens)
```

## Por qué PostGIS (y no solo columnas lat/lng)

| Necesidad | Solución PostGIS |
|---|---|
| "Hospedajes a 5 km de mi casa" | `ST_DWithin(geom, punto, 5000)` con **índice GIST** → milisegundos aunque haya millones de filas |
| "Cuidadores que cubren mi dirección" | Radio de cobertura + `ST_DWithin` |
| Ordenar por cercanía | `ST_Distance` |
| Futuro: "¿qué hay cerca de este hospedaje?" | `ST_Distance` entre puntos |

Con columnas simples `lat/lng` estas consultas serían scans completos: imposibles de escalar.

## Funciones listas para el backend

```sql
-- Búsqueda principal del buscador (todo en una llamada)
SELECT * FROM buscar_hospedajes(
  lat => 4.711, lng => -74.072, radio_m => 20000,
  f_desde => '2026-09-10', f_hasta => '2026-09-14',
  p_tipo => 'guarderia', p_convivencia => 'compartida', q => 'guardería'
);

-- Hospedajes disponibles en fechas
SELECT * FROM hospedajes_disponibles('2026-09-10', '2026-09-14');
```

## Notas de diseño

- **IDs UUID** (`gen_random_uuid()`) — sin exposición de secuencias en URLs/APIs.
- **`total` y `noches` generados** (`GENERATED ALWAYS`) — el cálculo nunca se desincroniza.
- **Emails `CITEXT`** — únicos case-insensitive.
- **Trigger de rating** — `resenas` mantiene `rating` y `num_resenas` del hospedaje automáticamente.
- **Anti-doble-reserva** — restricción `EXCLUDE USING gist` sobre rangos de fechas (requiere `btree_gist`; en producción se complementa con bloqueo de fila en la transacción).
- **Contraseñas** — nunca en claro: columna `password_hash` para bcrypt/argon2.
- **Auditoría** — tabla opcional para trazabilidad de cambios.
