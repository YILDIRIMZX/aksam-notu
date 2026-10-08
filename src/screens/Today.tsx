import { BellSimple, Check, ClockCounterClockwise, SunHorizon } from '@phosphor-icons/react'
import { useEffect, useState } from 'react'
import {
  emptyNote,
  formatDay,
  isBlank,
  isMorning,
  loadNote,
  previousKey,
  saveNote,
  type Alarm,
  type Note,
} from '../lib/notes'
import { Button, Card, FieldLabel, Page, cx, fieldClass } from '../ui'
import NoteView from './NoteView'

export default function Today({ day, onOpen }: { day: string; onOpen: (v: 'history' | 'settings') => void }) {
  const [note, setNote] = useState<Note>(() => emptyNote(day))
  const [saved, setSaved] = useState<Note | null>(null)
  const [yesterday, setYesterday] = useState<Note | null>(null)
  const [ready, setReady] = useState(false)

  useEffect(() => {
    let alive = true
    Promise.all([loadNote(day), isMorning() ? loadNote(previousKey(day)) : undefined]).then(([today, prev]) => {
      if (!alive) return
      if (today) {
        setNote(today)
        setSaved(today)
      }
      setYesterday(prev && !isBlank(prev) ? prev : null)
      setReady(true)
    })
    return () => {
      alive = false
    }
  }, [day])

  const dirty =
    !saved
      ? !isBlank(note)
      : note.problem !== saved.problem ||
        note.firstStep !== saved.firstStep ||
        note.alarm !== saved.alarm ||
        note.alarmSentence !== saved.alarmSentence

  const update = (patch: Partial<Note>) => setNote((n) => ({ ...n, ...patch }))
  const toggleAlarm = (value: Exclude<Alarm, null>) => update({ alarm: note.alarm === value ? null : value })

  async function save() {
    const next = await saveNote(note)
    setNote(next)
    setSaved(next)
  }

  const savedTime = saved?.savedAt
    ? new Date(saved.savedAt).toLocaleTimeString('tr-TR', { hour: '2-digit', minute: '2-digit' })
    : ''

  return (
    <Page eyebrow="Akşam Notu" title={formatDay(day)}>
      {yesterday && (
        <Card className="mb-4 bg-accent-soft shadow-none">
          <p className="mb-3 flex items-center gap-2 text-[14px] font-semibold text-accent-deep">
            <SunHorizon size={18} weight="bold" />
            Dün akşam yazdığın
          </p>
          <NoteView note={yesterday} />
        </Card>
      )}

      <Card className={cx('transition-opacity', !ready && 'opacity-0')}>
        <h2 className="text-[19px] font-[650] tracking-[-0.01em]">Yatmadan önce üç satır</h2>
        <p className="mt-1 mb-5 text-[14.5px] text-muted">Hepsi boş kalabilir.</p>

        <div className="space-y-5">
          <div>
            <FieldLabel n={1} htmlFor="problem">
              Açıkta kalan problem
            </FieldLabel>
            <textarea
              id="problem"
              rows={2}
              value={note.problem}
              onChange={(e) => update({ problem: e.target.value })}
              className={cx(fieldClass, 'resize-none field-sizing-content min-h-[76px]')}
            />
          </div>

          <div>
            <FieldLabel n={2} htmlFor="step">
              Yarın atacağım ilk adım
            </FieldLabel>
            <textarea
              id="step"
              rows={2}
              value={note.firstStep}
              onChange={(e) => update({ firstStep: e.target.value })}
              className={cx(fieldClass, 'resize-none field-sizing-content min-h-[76px]')}
            />
          </div>

          <div>
            <FieldLabel n={3}>Bugün alarm çaldı mı?</FieldLabel>
            <div role="radiogroup" aria-label="Bugün alarm çaldı mı?" className="flex gap-2">
              {(
                [
                  ['yes', 'Evet'],
                  ['no', 'Hayır'],
                ] as const
              ).map(([value, label]) => (
                <button
                  key={value}
                  role="radio"
                  aria-checked={note.alarm === value}
                  onClick={() => toggleAlarm(value)}
                  className={cx(
                    'h-11 flex-1 rounded-full text-[15.5px] font-medium transition-colors duration-200',
                    note.alarm === value ? 'bg-accent text-accent-ink' : 'bg-surface-2 text-ink',
                  )}
                >
                  {label}
                </button>
              ))}
            </div>
            {note.alarm === 'yes' && (
              <input
                aria-label="Hangi cümleydi?"
                placeholder="Hangi cümleydi? (isteğe bağlı)"
                value={note.alarmSentence}
                onChange={(e) => update({ alarmSentence: e.target.value })}
                className={cx(fieldClass, 'mt-3')}
              />
            )}
          </div>
        </div>

        <Button onClick={save} disabled={!dirty} className="mt-6 w-full">
          {saved && !dirty ? (
            <>
              <Check size={18} weight="bold" />
              Kaydedildi · {savedTime}
            </>
          ) : (
            'Kaydet'
          )}
        </Button>
      </Card>

      <nav className="mt-4 flex justify-center gap-2">
        <Button variant="ghost" onClick={() => onOpen('history')}>
          <ClockCounterClockwise size={18} />
          Geçmiş
        </Button>
        <Button variant="ghost" onClick={() => onOpen('settings')}>
          <BellSimple size={18} />
          Bildirim
        </Button>
      </nav>
    </Page>
  )
}
