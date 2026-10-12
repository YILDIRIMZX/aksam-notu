/// <reference lib="webworker" />
import { clientsClaim } from 'workbox-core'
import { cleanupOutdatedCaches, createHandlerBoundToURL, precacheAndRoute } from 'workbox-precaching'
import { NavigationRoute, registerRoute } from 'workbox-routing'
import config from '../push.config.json'

declare const self: ServiceWorkerGlobalScope & { __WB_MANIFEST: Array<{ url: string; revision: string | null }> }

self.skipWaiting()
clientsClaim()
precacheAndRoute(self.__WB_MANIFEST)
cleanupOutdatedCaches()
registerRoute(new NavigationRoute(createHandlerBoundToURL('index.html')))

const FALLBACK = config.reminder

// iOS revokes the subscription if a push arrives without a visible notification, so every push shows one.
self.addEventListener('push', (event) => {
  let data: { title?: string; body?: string } = {}
  try {
    data = event.data?.json() ?? {}
  } catch {
    // Plain-text or empty payloads fall back to the default reminder.
  }
  const options: NotificationOptions = {
    body: data.body || FALLBACK.body,
    icon: 'pwa-192.png',
    badge: 'pwa-192.png',
    data: { url: self.registration.scope },
  }

  // No tag: a notification with the same tag would silently replace the old one, so a notification from the evening might not appear.
  // Every reminder without a tag appears separately and is always visible.
  // The cost: if not cleared, they accumulate in the Notification Center. Since there is only one per day, we accept this.

  event.waitUntil(self.registration.showNotification(data.title || FALLBACK.title, options))
})

self.addEventListener('notificationclick', (event) => {
  event.notification.close()
  const url = (event.notification.data as { url?: string } | null)?.url ?? self.registration.scope
  event.waitUntil(
    (async () => {
      const windows = await self.clients.matchAll({ type: 'window', includeUncontrolled: true })
      const open = windows.find((w) => w.url.startsWith(self.registration.scope))
      if (open) return open.focus()
      return self.clients.openWindow(url)
    })(),
  )
})
