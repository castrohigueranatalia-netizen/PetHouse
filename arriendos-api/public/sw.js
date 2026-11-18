// ============================================================
// ARRIENDOS CARTAGENA · Service Worker (notificaciones push)
// ============================================================
self.addEventListener('push', (event) => {
  let datos = {}
  try { datos = event.data ? event.data.json() : {} } catch { datos = { body: event.data ? event.data.text() : '' } }

  const titulo = datos.title || 'Arriendos Cartagena'
  event.waitUntil(
    self.registration.showNotification(titulo, {
      body: datos.body || '',
      tag: datos.tag || undefined,
      data: { url: datos.url || '/' }
    })
  )
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = event.notification.data?.url || '/'
  event.waitUntil(
    clients.matchAll({ type: 'window' }).then((lista) => {
      for (const cliente of lista) {
        if ('focus' in cliente) return cliente.focus()
      }
      if (clients.openWindow) return clients.openWindow(url)
    })
  )
})
