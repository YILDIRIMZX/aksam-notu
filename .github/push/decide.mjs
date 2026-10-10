// Decides whether the evening reminder should be sent now.
// Env: SOURCE (schedule | pc | phone | manual), AT (the device's local time with its UTC offset,
// e.g. 2026-10-09T23:19:30+03:00), TEST, START_HOUR, LAST (evening of the last reminder), NOW (tests only).
// Writes evening=… and send=… to $GITHUB_OUTPUT. The log states only the decision: the repository is public.
import { appendFileSync } from 'node:fs'

/** The evening lasts until 05:00, so 00:30 still belongs to the day before. */
const ROLLOVER_HOUR = 5
/** A request that waited longer than this in GitHub's queue is no longer an evening reminder. */
const MAX_AGE_MIN = 90
/** Scheduled runs only send in this window; GitHub sometimes starts them hours late. */
const SCHEDULE_FROM = 22 * 60
const SCHEDULE_UNTIL = 23 * 60 + 30
const FALLBACK_ZONE = 'Europe/Istanbul'

const pad = (n) => String(n).padStart(2, '0')

/** Wall-clock fields of an instant at a fixed UTC offset (minutes). */
function wallClock(instantMs, offsetMin) {
  const d = new Date(instantMs + offsetMin * 60_000)
  return { y: d.getUTCFullYear(), m: d.getUTCMonth() + 1, d: d.getUTCDate(), h: d.getUTCHours(), min: d.getUTCMinutes() }
}

function zoneOffsetMin(instantMs, timeZone) {
  const parts = Object.fromEntries(
    new Intl.DateTimeFormat('en-US', { timeZone, hourCycle: 'h23', year: 'numeric', month: 'numeric', day: 'numeric', hour: 'numeric', minute: 'numeric' })
      .formatToParts(new Date(instantMs))
      .map((p) => [p.type, Number(p.value)]),
  )
  const asUtc = Date.UTC(parts.year, parts.month - 1, parts.day, parts.hour, parts.minute)
  return Math.round((asUtc - Math.floor(instantMs / 60_000) * 60_000) / 60_000)
}

/** Parses "YYYY-MM-DDTHH:mm[:ss][.fff](Z|±HH:mm)". Returns null without an explicit offset. */
function parseDeviceTime(text) {
  const m = /^(\d{4})-(\d{2})-(\d{2})T(\d{2}):(\d{2})(?::(\d{2})(?:\.\d+)?)?(Z|([+-])(\d{2}):?(\d{2}))$/.exec(text.trim())
  if (!m) return null
  const offsetMin = m[7] === 'Z' ? 0 : (m[8] === '-' ? -1 : 1) * (Number(m[9]) * 60 + Number(m[10]))
  const localMs = Date.UTC(+m[1], +m[2] - 1, +m[3], +m[4], +m[5], +(m[6] ?? 0))
  return { instantMs: localMs - offsetMin * 60_000, offsetMin }
}

export function decide({ source = 'schedule', at = '', test = false, startHour = 21, last = '', nowMs = Date.now() }) {
  let instantMs = nowMs
  let offsetMin = zoneOffsetMin(nowMs, FALLBACK_ZONE)
  let send = true
  let reason = 'Sending.'

  if (source !== 'schedule' && at) {
    const parsed = parseDeviceTime(at)
    if (parsed) ({ instantMs, offsetMin } = parsed)
  }

  const local = wallClock(instantMs, offsetMin)
  const evening = wallClock(instantMs - ROLLOVER_HOUR * 3_600_000, offsetMin)
  const eveningKey = `${evening.y}-${pad(evening.m)}-${pad(evening.d)}`
  const minuteOfDay = local.h * 60 + local.min

  if (test) {
    reason = 'Test run: sending without recording.'
  } else if (last === eveningKey) {
    send = false
    reason = 'Already sent this evening.'
  } else if (source === 'schedule') {
    if (minuteOfDay < SCHEDULE_FROM || minuteOfDay >= SCHEDULE_UNTIL) {
      send = false
      reason = 'Scheduled run started outside 22:00-23:30 (GitHub was late or early). Skipping.'
    }
  } else if ((nowMs - instantMs) / 60_000 > MAX_AGE_MIN) {
    send = false
    reason = `The request is more than ${MAX_AGE_MIN} minutes old. Skipping.`
  } else if (local.h < startHour && local.h >= ROLLOVER_HOUR) {
    send = false
    reason = 'Outside the evening window.'
  }

  return { send, evening: eveningKey, reason }
}

if (process.argv[1]?.endsWith('decide.mjs')) {
  const env = process.env
  const result = decide({
    source: env.SOURCE || 'schedule',
    at: env.AT || '',
    test: env.TEST === 'true',
    startHour: Number(env.START_HOUR || 21),
    last: (env.LAST || '').trim(),
    nowMs: env.NOW ? Date.parse(env.NOW) : Date.now(),
  })
  console.log(result.reason)
  const out = `evening=${result.evening}\nsend=${result.send}\n`
  if (env.GITHUB_OUTPUT) appendFileSync(env.GITHUB_OUTPUT, out)
  else process.stdout.write(out)
}
