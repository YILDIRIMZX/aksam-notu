// Run: node .github/push/decide.test.mjs
import { decide } from './decide.mjs'

const cases = [
  // [name, input, expected send, expected evening]
  ['Late GitHub schedule at 02:32 (the bug)', { source: 'schedule', nowMs: Date.parse('2026-10-09T23:32:00Z') }, false, '2026-10-09'],
  ['Schedule 22:01 Istanbul', { source: 'schedule', nowMs: Date.parse('2026-10-09T19:01:00Z') }, true, '2026-10-09'],
  ['Schedule 21:45 (before window)', { source: 'schedule', nowMs: Date.parse('2026-10-09T18:45:00Z') }, false, '2026-10-09'],
  ['Schedule 23:29', { source: 'schedule', nowMs: Date.parse('2026-10-09T20:29:00Z') }, true, '2026-10-09'],
  ['Schedule, already sent', { source: 'schedule', last: '2026-10-09', nowMs: Date.parse('2026-10-09T19:01:00Z') }, false, '2026-10-09'],
  ['PC shutdown 23:19 +03:00', { source: 'pc', at: '2026-10-09T23:19:30+03:00', nowMs: Date.parse('2026-10-09T20:19:50Z') }, true, '2026-10-09'],
  ['PC shutdown 18:11 (too early)', { source: 'pc', at: '2026-10-09T18:11:00+03:00', nowMs: Date.parse('2026-10-09T15:11:20Z') }, false, '2026-10-09'],
  ['PC shutdown 00:40 counts for previous evening', { source: 'pc', at: '2026-10-10T00:40:00+03:00', nowMs: Date.parse('2026-10-09T21:40:30Z') }, true, '2026-10-09'],
  ['PC request stuck 3 hours in queue', { source: 'pc', at: '2026-10-09T23:19:30+03:00', nowMs: Date.parse('2026-10-10T02:30:00Z') }, false, '2026-10-09'],
  ['PC in another time zone (UTC+1, 21:30 local)', { source: 'pc', at: '2026-10-09T21:30:00+01:00', nowMs: Date.parse('2026-10-09T20:30:10Z') }, true, '2026-10-09'],
  ['PC without at falls back to Istanbul now', { source: 'pc', nowMs: Date.parse('2026-10-09T18:30:00Z') }, true, '2026-10-09'],
  ['PC, already sent', { source: 'pc', at: '2026-10-09T23:19:30+03:00', last: '2026-10-09', nowMs: Date.parse('2026-10-09T20:20:00Z') }, false, '2026-10-09'],
  ['Test ignores everything', { source: 'pc', test: true, last: '2026-10-08', at: '2026-10-08T16:10:00+03:00', nowMs: Date.parse('2026-10-08T13:10:00Z') }, true, '2026-10-08'],
  ['Malformed at falls back to now', { source: 'pc', at: 'yesterday', nowMs: Date.parse('2026-10-09T19:30:00Z') }, true, '2026-10-09'],
]

let failed = 0
for (const [name, input, send, evening] of cases) {
  const r = decide(input)
  const ok = r.send === send && r.evening === evening
  if (!ok) failed++
  console.log(`${ok ? 'OK  ' : 'FAIL'} ${name} -> send=${r.send} evening=${r.evening} (${r.reason})`)
}
process.exit(failed ? 1 : 0)
