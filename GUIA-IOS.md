# 📱 Guía: Pethouse como aplicación de iOS

Tienes **dos formas** de usar Pethouse en un iPhone. Las dos ya están preparadas en el proyecto:

| Opción | Qué es | ¿Necesitas Mac? | ¿Necesitas cuenta de Apple? |
|---|---|---|---|
| **A. App instalable (PWA)** | Se agrega a la pantalla de inicio del iPhone como una app, con icono, pantalla completa y modo offline | ❌ No | ❌ No |
| **B. App nativa (Capacitor)** | Proyecto Xcode listo para compilar y publicar en la App Store / TestFlight | ✅ Sí (Mac con Xcode) | ✅ Sí (Apple ID gratis o programa $99/año) |

---

## 🍎 Opción A — Instalar como app en tu iPhone (sin Mac, 1 minuto)

Tu sitio ya está publicado en GitHub Pages y tiene todo lo necesario (manifest, icono, service worker).

1. Abre Safari en tu iPhone y entra a:
   **`https://castrohigueranatalia-netizen.github.io/PetHouse/`**
2. Toca el botón **Compartir** (cuadrito con flecha ↑, abajo en Safari).
3. Desliza las opciones y toca **"Añadir a pantalla de inicio"** (Add to Home Screen).
4. Pulsa **Añadir** (el nombre saldrá "Pethouse" con su icono).
5. ¡Listo! En tu pantalla de inicio tienes **Pethouse como una app**: se abre a pantalla completa, sin la barra del navegador, y funciona **sin internet** (queda guardada en caché).

> Si la web aún no carga, espera 1-2 min (GitHub Pages tarda en publicar el primer build).

---

## 🛠️ Opción B — App nativa con Xcode (para App Store / TestFlight)

El proyecto nativo está en la carpeta **`pethouse-ios/`** del repositorio:

```
pethouse-ios/
├── capacitor.config.json   ← appId, nombre
├── web/                    ← la plataforma web (ya copiada)
└── ios/
    └── App/
        ├── App.xcworkspace ← proyecto a abrir en Xcode
        └── App/
            ├── Info.plist  ← nombre "Pethouse" + red local permitida
            └── public/     ← la web dentro de la app
```

### Paso 1 — Requisitos (en tu Mac)
- **Xcode** (gratis desde la App Store; incluye iOS Simulator)
- **Node.js** (para Capacitor)

### Paso 2 — Clona el proyecto y abre en Xcode
```bash
git clone https://github.com/castrohigueranatalia-netizen/PetHouse.git
cd PetHouse/pethouse-ios
npm install
npx cap sync ios          # copia la web dentro de la app
npx cap open ios          # abre Xcode
```

### Paso 3 — Configura tu equipo (en Xcode)
1. Selecciona el proyecto **App** (barra izquierda).
2. En **Signing & Capabilities**:
   - Marca **Automatically manage signing**.
   - En **Team**: elige tu Apple ID (Xcode → Settings → Accounts → agrega tu Apple ID). Sin pagar puedes probar en tu propio iPhone (7 días de validez); para App Store se necesita el programa de desarrollador ($99/año).
   - Cambia el **Bundle Identifier** a uno único, p. ej. `co.tunombre.pethouse`.
3. En el menú superior elige tu **iPhone** (conectado por cable y con "Modo desarrollador" activado en Ajustes → Privacidad) o un **Simulador**.

### Paso 4 — Ejecutar
- Pulsa el botón **Play (▶)**. La app compila y se instala en tu iPhone: **Pethouse funciona como app nativa** (toda la plataforma dentro de una ventana WebView).

### Paso 5 — Publicar en App Store / TestFlight (opcional)
1. En Xcode: **Product → Archive**.
2. En la ventana del Organizer: **Distribute App** → **App Store Connect**.
3. Sigue el asistente (crea la app en [appstoreconnect.apple.com](https://appstoreconnect.apple.com) con el mismo Bundle ID).
4. Los evaluadores pueden instalarla vía **TestFlight** antes de la revisión de Apple.

---

## 🔌 La IA dentro de la app

- **App nativa (Opción B):** el chat de IA puede llamar a Gemini **directo desde la app** (WKWebView permite HTTPS). En el panel ⚙ del chat elige *"Gemini directo (clave en el navegador)"* y pega tu clave de aistudio.google.com. La clave queda solo en tu teléfono.
- También puedes apuntar a tu **servidor** (`servidor-ia.js` desplegado en un hosting con HTTPS, p. ej. Render/Railway) poniendo su URL en *"API del servidor"*.
- En la versión instalada por Safari (Opción A) funciona el modo offline + Gemini directo.

## ♻️ Actualizar la app cuando haya cambios

- **Opción A (PWA):** la app se actualiza sola al abrir con internet (el service worker refresca). También puedes borrarla y volver a añadirla.
- **Opción B (nativa):** en la Mac, `git pull`, `npx cap sync ios` y vuelve a compilar con ▶ (o Archive para TestFlight).

---

## 📦 Resumen de archivos agregados para iOS

| Archivo | Función |
|---|---|
| `manifest.webmanifest` | Configuración PWA (nombre, iconos, pantalla standalone) |
| `sw.js` | Service worker: funciona offline y como app instalable |
| `apple-touch-icon.png` (180px) · `icon-192.png` · `icon-512.png` | Icono de la app (huella coral sobre fondo #FB3F57) |
| `pethouse-ios/` | Proyecto nativo Capacitor con `ios/App/App.xcworkspace` |
| Metaetiquetas en `index.html` | `apple-mobile-web-app-capable`, `theme-color`, etc. |
