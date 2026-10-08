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
  event.waitUntil(
    self.registration.showNotification(data.title || FALLBACK.title, {
      body: data.body || FALLBACK.body,
      icon: 'pwa-192.png',
      badge: 'pwa-192.png',
      // The same tag replaces an earlier reminder instead of stacking a second one.
      tag: 'aksam-notu',
      data: { url: self.registration.scope },
    }),
  )
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
