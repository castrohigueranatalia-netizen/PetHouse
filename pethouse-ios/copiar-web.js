// Copia la plataforma web (index.html + PWA) dentro del proyecto iOS
import { cpSync, mkdirSync, rmSync } from 'fs'

rmSync('web', { recursive: true, force: true })
mkdirSync('web', { recursive: true })
for (const f of ['index.html', 'manifest.webmanifest', 'sw.js', 'apple-touch-icon.png', 'icon-192.png', 'icon-512.png']) {
  cpSync(`../${f}`, `web/${f}`)
}
console.log('✔ web/ actualizada desde pethouse-html/')
