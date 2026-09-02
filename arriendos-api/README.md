# 🏠 Arriendos Cartagena — Control de reservas

Reemplazo del Excel donde se llevan las reservas de los 7 apartamentos.
API en Node.js + Express + PostgreSQL, con una página web autocontenida
(`public/index.html`) para consultar el calendario y agregar/editar reservas,
y sincronización automática de calendario con **Booking** y **Airbnb** vía iCal.

## Arrancar en local

```bash
cd arriendos-api

# 1) Base de datos (PostgreSQL en Docker, puerto 5433)
cd db && docker compose up -d && cd ..

# 2) Configuración
cp .env.example .env

# 3) Dependencias y arranque
npm install
npm run dev
```

Abre **http://localhost:3002**. El usuario inicial queda creado por el seed:

- Correo: `papa@arriendoscartagena.com`
- Contraseña: `cambiame123`

Cámbiala apenas entres, con el botón **"Cambiar contraseña"** (arriba a la derecha).
Edita también los 7 apartamentos en `db/02-seed.sql` (nombres, precios) *antes*
de levantar la base por primera vez — o después, desde la pestaña **Apartamentos**
de la propia app.

## Cómo funciona la sincronización con Booking/Airbnb

Booking.com y Airbnb **no dan acceso libre a una API** para leer o crear
reservas — esa API ("Connectivity"/"Channel Manager") solo se otorga a
empresas registradas como conectividad, con un acuerdo comercial formal. Para
un anfitrión con 7 apartamentos eso no aplica. Lo que sí ofrecen ambas
plataformas, sin ningún trámite, es un **calendario iCal** por cada anuncio:

1. **Traer las reservas de Booking a esta app (importar):**
   En el *Extranet* de Booking → tu propiedad → **Calendario → Sincronizar
   calendarios → Exportar calendario** → copia el link `.ics`. Pégalo en la
   pestaña **Apartamentos** de esta app, en el campo *"Link para IMPORTAR"*,
   y dale **Guardar**. A partir de ahí la app revisa ese link cada
   `SYNC_INTERVAL_MIN` minutos (30 por defecto) y crea/actualiza las reservas
   solas. También hay un botón **"Sincronizar ahora"** para no esperar.
   En Airbnb el mismo tipo de link está en *Calendario → Disponibilidad →
   Exportar calendario*.

2. **Bloquear en Booking/Airbnb lo que se reserva aquí (exportar):**
   Cada apartamento tiene su propio link de exportación (con un token
   secreto) en la misma pestaña, campo *"Link para EXPORTAR"*. Cópialo y
   pégalo en Booking/Airbnb como **"Importar calendario"**. Así, cuando se
   registre a mano una reserva que llegó por WhatsApp o de forma directa,
   Booking y Airbnb también bloquean esa fecha — evita la doble reserva
   entre plataformas.

**Limitación real e importante:** el calendario iCal de Booking/Airbnb solo
trae **fechas bloqueadas**, no el nombre, teléfono ni el valor de la reserva
(por privacidad de la plataforma). Esas reservas quedan creadas en la app
marcadas como *"Booking"* pero con el huésped vacío; el nombre/teléfono/precio
hay que completarlos a mano (usando el botón **Editar**) con el correo o la
notificación que manda Booking por cada reserva. Es decir: la app sí evita
que se te olvide bloquear un apartamento o que se cruce con otra reserva,
pero no reemplaza por completo leer la notificación de Booking.

Si en el futuro el negocio crece y conviene volverse *channel manager*
registrado (API real, sincronización con precios y datos completos), el
punto de partida es la documentación de Booking para partners de
conectividad — pero para el tamaño actual (7 apartamentos, un solo dueño),
iCal es la opción que funciona sin depender de que Booking apruebe nada.

## Asistente de preguntas (botón 💬)

Dentro de la app hay un botón flotante para hacerle preguntas a la reservas
en lenguaje natural, por ejemplo:

- *"¿Cuántas noches libres tiene el Apto 3 en octubre?"*
- *"¿Cuánto facturé este mes?"*
- *"¿Cuántas reservas de Booking hay pendientes de completar el nombre del huésped?"*

Funciona con la API de Claude (Anthropic): el modelo consulta la base de
datos (solo lectura) y calcula la respuesta con los datos reales, nunca
inventa cifras. Para activarlo:

1. Crea una clave en **https://console.anthropic.com/settings/keys**
2. Pégala en `.env` como `ANTHROPIC_API_KEY=...`
3. Reinicia el servidor (`npm run dev`)

Sin esa clave, la app funciona igual — el botón del asistente solo muestra
un aviso de que falta configurarlo. El costo es por uso (no hay suscripción):
cada pregunta consulta el modelo Claude Opus 5 y normalmente cuesta una
fracción de centavo de dólar; para el volumen de preguntas de un solo
usuario esto es prácticamente insignificante, pero el costo corre por la
cuenta de Anthropic asociada a esa clave.

## Qué evita la base de datos

- **Doble reserva:** no se puede crear/editar una reserva confirmada que se
  cruce en fechas con otra del mismo apartamento (la base de datos lo
  rechaza, no solo la pantalla).
- **Reservas duplicadas al sincronizar:** cada evento de Booking/Airbnb se
  identifica por su UID; sincronizar de nuevo no crea copias.
- **Reservas "fantasma":** si una reserva se cancela en Booking, al
  sincronizar de nuevo esta app la marca `cancelada` automáticamente.

## Estructura

```
arriendos-api/
├── db/
│   ├── 01-esquema.sql      Tablas: usuarios, apartamentos, reservas
│   ├── 02-seed.sql         Usuario inicial + los 7 apartamentos
│   └── docker-compose.yml  PostgreSQL local (puerto 5433)
├── src/
│   ├── routes/              auth · apartamentos · reservas · ical · asistente
│   ├── services/             icalSync (importar) · icalExport (exportar) · asistente (Claude API)
│   └── ...
└── public/index.html        Frontend (una sola página, sin build)
```

## Producción

Para que Booking/Airbnb puedan leer el link de exportación y para que tu
papá pueda entrar desde el celular, esto necesita quedar accesible por
internet — no solo en tu computador. Opciones sencillas y económicas para
este tamaño de proyecto: Railway, Render o un VPS pequeño, con la misma
base de datos PostgreSQL (managed o en el propio servidor). Al desplegar,
actualiza `PUBLIC_URL` en `.env` a la URL real, para que los links de
exportación que genera la app apunten al lugar correcto.
