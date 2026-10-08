import config from '../../push.config.json'

export type PushState = 'unsupported' | 'needs-install' | 'denied' | 'off' | 'on'

const isIOS = () => /iPad|iPhone|iPod/.test(navigator.userAgent) || (navigator.platform === 'MacIntel' && navigator.maxTouchPoints > 1)
const isStandalone = () =>
  window.matchMedia('(display-mode: standalone)').matches || (navigator as Navigator & { standalone?: boolean }).standalone === true

function urlBase64ToUint8Array(base64: string): Uint8Array<ArrayBuffer> {
  const padding = '='.repeat((4 - (base64.length % 4)) % 4)
  const raw = atob((base64 + padding).replace(/-/g, '+').replace(/_/g, '/'))
  const out = new Uint8Array(new ArrayBuffer(raw.length))
  for (let i = 0; i < raw.length; i++) out[i] = raw.charCodeAt(i)
  return out
}

export async function pushState(): Promise<PushState> {
  // On iPhone, Web Push exists only for apps added to the Home Screen.
  if (isIOS() && !isStandalone()) return 'needs-install'
  if (!('serviceWorker' in navigator) || !('PushManager' in window) || !('Notification' in window)) return 'unsupported'
  if (Notification.permission === 'denied') return 'denied'
  const reg = await navigator.serviceWorker.getRegistration()
  const sub = await reg?.pushManager.getSubscription()
  return sub ? 'on' : 'off'
}

/** Asks for permission and returns the subscription as the JSON the reminder workflow expects. */
export async function subscribe(): Promise<string> {
  const permission = await Notification.requestPermission()
  if (permission !== 'granted') throw new Error('permission')
  const reg = await navigator.serviceWorker.ready
  const sub =
    (await reg.pushManager.getSubscription()) ??
    (await reg.pushManager.subscribe({
      userVisibleOnly: true,
      applicationServerKey: urlBase64ToUint8Array(config.vapidPublicKey),
    }))
  return JSON.stringify(sub.toJSON())
}

export async function currentSubscription(): Promise<string | null> {
  const reg = await navigator.serviceWorker.getRegistration()
  const sub = await reg?.pushManager.getSubscription()
  return sub ? JSON.stringify(sub.toJSON()) : null
}

export async function unsubscribe() {
  const reg = await navigator.serviceWorker.getRegistration()
  await (await reg?.pushManager.getSubscription())?.unsubscribe()
}

/** Shows the reminder locally, to check how it looks without going through GitHub. */
export async function showTestNotification() {
  const reg = await navigator.serviceWorker.ready
  await reg.showNotification(config.reminder.title, {
    body: config.reminder.body,
    icon: 'pwa-192.png',
    tag: 'aksam-notu',
  })
}
