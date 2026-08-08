/* ============================================================
   PETHOUSE · Service Worker
   Guarda la plataforma en caché para que funcione OFFLINE y
   como aplicación instalable (PWA) en iOS / Android / escritorio.
   Estrategia: red primero, caché como respaldo.
   ============================================================ */
const CACHE = 'pethouse-v1';

self.addEventListener('install', (e) => {
  self.skipWaiting();
  e.waitUntil(
    caches.open(CACHE).then((c) => c.addAll(['./'])).catch(() => {})
  );
});

self.addEventListener('activate', (e) => {
  e.waitUntil(
    caches.keys()
      .then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
      .then(() => self.clients.claim())
  );
});

self.addEventListener('fetch', (e) => {
  const req = e.request;
  const url = new URL(req.url);

  // Solo GET del mismo origen (no interferir con APIs externas)
  if (req.method !== 'GET' || url.origin !== location.origin) return;

  e.respondWith(
    caches.open(CACHE).then(async (cache) => {
      try {
        const fresh = await fetch(req);
        if (fresh && fresh.ok) cache.put(req, fresh.clone());
        return fresh;
      } catch (err) {
        const cached = await cache.match(req, { ignoreSearch: true });
        if (cached) return cached;
        const home = await cache.match('./');
        if (home) return home;
        return new Response('Sin conexión', { status: 503 });
      }
    })
  );
});
