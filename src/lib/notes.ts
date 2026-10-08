import { clear, createStore, entries, get, set } from 'idb-keyval'

export type Alarm = 'yes' | 'no' | null

export type Note = {
  /** The evening this note belongs to, as YYYY-MM-DD. */
  date: string
  problem: string
  firstStep: string
  alarm: Alarm
  alarmSentence: string
  savedAt: string
}

const store = createStore('aksam-notu', 'notes')

/**
 * An evening lasts until 05:00, so a note written at 00:30 still belongs to the day before.
 * That keeps "yesterday's note" right for late nights.
 */
const DAY_ROLLOVER_HOUR = 5

const pad = (n: number) => String(n).padStart(2, '0')
const toKey = (d: Date) => `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`

export function eveningKey(now = new Date()): string {
  const d = new Date(now)
  d.setHours(d.getHours() - DAY_ROLLOVER_HOUR)
  return toKey(d)
}

export function previousKey(key: string): string {
  const [y, m, d] = key.split('-').map(Number)
  return toKey(new Date(y, m - 1, d - 1))
}

/** Morning: the time to show last evening's note first. */
export function isMorning(now = new Date()): boolean {
  const h = now.getHours()
  return h >= DAY_ROLLOVER_HOUR && h < 17
}

export function formatDay(key: string, withWeekday = true): string {
  const [y, m, d] = key.split('-').map(Number)
  return new Date(y, m - 1, d).toLocaleDateString('tr-TR', {
    day: 'numeric',
    month: 'long',
    ...(withWeekday ? { weekday: 'long' } : {}),
  })
}

export const emptyNote = (date: string): Note => ({
  date,
  problem: '',
  firstStep: '',
  alarm: null,
  alarmSentence: '',
  savedAt: '',
})

export const isBlank = (n: Note) => !n.problem.trim() && !n.firstStep.trim() && n.alarm === null && !n.alarmSentence.trim()

export const loadNote = (date: string) => get<Note>(date, store)

export async function saveNote(note: Note): Promise<Note> {
  const saved = { ...note, savedAt: new Date().toISOString() }
  await set(note.date, saved, store)
  return saved
}

export async function allNotes(): Promise<Note[]> {
  const rows = await entries<string, Note>(store)
  return rows.map(([, n]) => n).sort((a, b) => b.date.localeCompare(a.date))
}

export const deleteAllNotes = () => clear(store)

/**
 * Asks the browser not to evict notes under storage pressure. iOS may otherwise clear
 * website data that has not been used for a while.
 */
export async function requestPersistence() {
  try {
    if (navigator.storage?.persist && !(await navigator.storage.persisted())) await navigator.storage.persist()
  } catch {
    // Not supported: notes still work, they are just not marked as persistent.
  }
}

export async function downloadBackup() {
  const notes = await allNotes()
  const blob = new Blob([JSON.stringify({ app: 'aksam-notu', exportedAt: new Date().toISOString(), notes }, null, 2)], {
    type: 'application/json',
  })
  const a = document.createElement('a')
  a.href = URL.createObjectURL(blob)
  a.download = `aksam-notu-${eveningKey()}.json`
  a.click()
  setTimeout(() => URL.revokeObjectURL(a.href), 1000)
}
