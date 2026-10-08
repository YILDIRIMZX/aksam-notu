// Sends the evening reminder to every subscribed device.
// Secrets: VAPID_PRIVATE_KEY, PUSH_SUBSCRIPTIONS (one subscription object or an array of them).
import { readFileSync } from 'node:fs'
import webpush from 'web-push'

const config = JSON.parse(readFileSync(new URL('../../push.config.json', import.meta.url), 'utf8'))
const { VAPID_PRIVATE_KEY, PUSH_SUBSCRIPTIONS, VAPID_SUBJECT } = process.env

if (!VAPID_PRIVATE_KEY || !PUSH_SUBSCRIPTIONS) {
  console.error('::error::VAPID_PRIVATE_KEY and PUSH_SUBSCRIPTIONS secrets are required. See README, "Setup".')
  process.exit(1)
}

let subscriptions
try {
  const parsed = JSON.parse(PUSH_SUBSCRIPTIONS)
  subscriptions = Array.isArray(parsed) ? parsed : [parsed]
} catch {
  console.error('::error::PUSH_SUBSCRIPTIONS is not valid JSON. Paste the code from the app exactly as copied.')
  process.exit(1)
}

// Apple requires a mailto: or https: subject. The app's own address keeps personal details out of the repo.
const [owner, repo] = config.repo.split('/')
webpush.setVapidDetails(VAPID_SUBJECT || `https://${owner.toLowerCase()}.github.io/${repo}/`, config.vapidPublicKey, VAPID_PRIVATE_KEY)

// The payload is a fixed sentence: no note content or personal data ever goes through a push service.
const payload = JSON.stringify(config.reminder)

let delivered = 0
for (const [i, sub] of subscriptions.entries()) {
  try {
    // A reminder that arrives hours late is no use, so it expires after 2 hours.
    await webpush.sendNotification(sub, payload, { TTL: 2 * 60 * 60, urgency: 'high', topic: 'aksam-notu' })
    delivered++
    console.log(`Device ${i + 1}: delivered`)
  } catch (err) {
    const gone = err.statusCode === 404 || err.statusCode === 410
    console.log(
      gone
        ? `::warning::Device ${i + 1}: subscription expired. Turn notifications off and on in the app and paste the new code.`
        : `::warning::Device ${i + 1}: failed (${err.statusCode ?? err.message})`,
    )
  }
}

if (!delivered) {
  console.error('::error::No device received the reminder.')
  process.exit(1)
}
