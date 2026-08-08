# 📱 Plan detallado: abrir Pethouse en Xcode (Mac)

Guía completa desde el ZIP descargado hasta ver la app funcionando.
Tiempo estimado total: **20-40 minutos** (la primera compilación es la más lenta).

---

## 🗺️ Antes de empezar: cómo funciona esto (30 segundos)

La app **no está programada en Swift**. Funciona así:

```
Tu app (Xcode) 
   └── WKWebView (navegador embebido de iOS)
          └── index.html + JS/CSS de Pethouse (la misma web que ya conoces)
```

Capacitor (la herramienta) envuelve la plataforma web en una "cáscara" nativa iOS:
te da el icono, la pantalla de inicio, el app-switcher, notificaciones futuras, etc.
Por eso **todos los cambios que hacemos en el HTML se reflejan en la app**.

---

## PASO 1 — Descomprime el ZIP

1. Doble clic en **`pethouse-ios.zip`** (el archivo que descargaste).
2. Se creará una carpeta llamada **`pethouse-ios/`** (déjala en Descargas o muévela a Documentos).
3. Entra en ella y verifica que existe la subcarpeta **`ios/`**.

> ⚠️ No muevas los archivos de lugar DESPUÉS de abrir Xcode: el proyecto guarda rutas relativas.

---

## PASO 2 — Instala los requisitos (solo la primera vez)

Abre la app **Terminal** (Buscar "Terminal" con Spotlight ⌘+Espacio) y ejecuta:

| Comando | Qué hace | ¿Si ya lo tienes? |
|---|---|---|
| `xcode-select --install` | Instala las herramientas de Xcode | Te dirá "already installed" |
| `brew install node` | Instala Node.js (para Capacitor) | Si no tienes Homebrew: primero `xcode-select --install` y luego `/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"` |
| `sudo gem install cocoapods` | Instala CocoaPods (gestor de dependencias iOS) | Te pedirá tu contraseña de Mac |

**Xcode** se instala desde la **App Store** (busca "Xcode", botón Obtener/Instalar, ~12 GB, tarda un rato).

---

## PASO 3 — Prepara el proyecto (Terminal, una sola vez)

```bash
cd ~/Downloads/pethouse-ios          # o donde hayas descomprimido
npm install                          # instala las herramientas de Capacitor (~1 min)
npx cap sync ios                     # copia la web dentro de la app y descarga pods
npx cap open ios                     # ABRE XCODE AUTOMÁTICAMENTE con el proyecto
```

Cuando termine, **Xcode se abrirá solo** mostrando el proyecto "App". ✔️

> ¿`npx cap sync` da error de CocoaPods? Vuelve a correrlo tras `sudo gem install cocoapods`.

---

## PASO 4 — Conoce Xcode (dónde estás parado)

Al abrir verás una ventana con:

```
┌────────────────────────────────────────────────────────────┐
│  ▶  |  App  |  iPhone 16 Pro        (barra superior)       │
├────────────────────────────────────────────────────────────┤
│  NAVEGADOR (izq.) │ EDITOR (centro) │  INSPECTOR (der.)    │
│  · App           │  Archivos .swift │  · Signing & Capab.  │
│  · AppTests      │  Info.plist      │  · Build Settings    │
│  · AppUITests    │  Assets.xcassets │                       │
└────────────────────────────────────────────────────────────┘
```

- **Navegador izquierdo**: lista de archivos del proyecto. No toques nada salvo lo indicado.
- **Centro**: editor de código (verás `AppDelegate.swift` — es la "cáscara").
- **Barra superior izquierda**: el botón **▶ Play** (compila y ejecuta).

> Tu código real (el HTML de Pethouse) vive dentro del proyecto en:
> `App/App/public/index.html` — puedes verlo en el navegador izquierdo.

---

## PASO 5 — Configura tu firma (lo único "personal")

1. En el **navegador izquierdo**, clic en el primer archivo (**App**, con icono azul).
2. En el editor (centro) verás las pestañas: **General / Signing & Capabilities / ...** → entra en **Signing & Capabilities**.
3. Marca **"Automatically manage signing"** (gestión automática).
4. En **Team** → clic → **Add an Account…**:
   - Se abre una ventana → **Apple ID** → **Continue**
   - Ingresa tu Apple ID y contraseña (el de tu iPhone)
   - Cierra la ventana y elige tu cuenta en **Team**
5. En **Bundle Identifier**: cámbialo a uno único, por ejemplo:
   `co.tunombre.pethouse` (sin espacios ni tildes)
6. Aparecerá una advertencia amarilla "no signing certificate found" → Xcode la **resuelve solo** cuando compiles (crea un certificado de desarrollo gratuito).

---

## PASO 6 — Elige dónde ejecutarla

En la **barra superior**, junto al botón ▶, hay un selector de dispositivo:

### Opción A — Simulador (recomendado para empezar)
1. Clic en el selector → **iOS Simulator** → elige un modelo (**iPhone 16 Pro**, etc.).
2. Pulsa **▶ (Play)**.
3. Espera: la **primera compilación tarda 2-5 minutos** (descarga el simulador la primera vez).
4. Se abrirá una ventana con un iPhone virtual → **¡Pethouse corriendo!** 🐾

### Opción B — Tu iPhone real
1. Conecta tu iPhone por **cable USB** a la Mac y desbloquéalo.
2. En el iPhone: **Ajustes → Privacidad y seguridad → Modo desarrollador → Activar** (y reinicia si te lo pide).
3. En el selector de Xcode elige **tu iPhone** (aparece por su nombre).
4. Pulsa **▶** → Xcode compila, instala y abre Pethouse en tu iPhone.
   - La primera vez el iPhone pregunta "¿Confiar en este desarrollador?" → **Confiar** (Ajustes → General → Gestión de VPN y dispositivos).
   - ⚠️ Con Apple ID gratuito la app expira a los **7 días**; vuelve a compilar para renovarla.

---

## PASO 7 — Qué deberías ver

- **Pantalla de inicio** (splash) blanca con el logo.
- La **plataforma Pethouse completa**: buscador, mapa, hospedajes, chat, actividades, IA.
- App a **pantalla completa** (sin barra de Safari), con el icono de la huella en el springboard.

---

## 🛠️ Solución de problemas comunes

| Problema | Solución |
|---|---|
| `npm: command not found` | Instala Node (Paso 2) y abre una Terminal nueva |
| `CocoaPods not installed` | `sudo gem install cocoapods` → `npx cap sync ios` de nuevo |
| Error de firma "No team" | Repite Paso 5 (agrega tu Apple ID) |
| "untrusted developer" en el iPhone | iPhone → Ajustes → General → Gestión de VPN y dispositivos → Confiar |
| Build lento la primera vez | Normal: descarga simulador + pods. Las siguientes son rápidas |
| La app se cierra al abrir | `npx cap sync ios` y vuelve a ▶ |
| Quieres cambiar algo (textos, colores) | Edita `web/index.html` y corre `npx cap sync ios` → ▶ |

---

## ♻️ Flujo de trabajo diario (cuando hagas cambios)

1. Aquí (en el chat) hacemos cambios y me dices **"sincroniza"**.
2. En la Mac: `cd ~/Downloads/pethouse-ios && git pull` (si clonaste) o descarga el ZIP nuevo.
3. `npx cap sync ios` → **▶** en Xcode.

---

## 🚀 Para App Store / TestFlight (cuando estés listo)

1. Xcode → **Product → Archive** (con el iPhone o "Any iOS Device" seleccionado).
2. En la ventana **Organizer**: selecciona el archive → **Distribute App** → **App Store Connect**.
3. Crea la app en [appstoreconnect.apple.com](https://appstoreconnect.apple.com) (mismo Bundle ID).
4. Sube el build → **TestFlight** para probadores → o **Envío a revisión** de Apple.
   - Requiere el **programa de desarrollador de Apple (US$99/año)** para distribución pública.
