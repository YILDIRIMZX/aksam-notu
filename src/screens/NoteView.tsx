import type { Note } from '../lib/notes'

/** Read-only rendering of a saved note. Empty boxes are simply left out. */
export default function NoteView({ note }: { note: Note }) {
  const rows: [string, string][] = []
  if (note.problem.trim()) rows.push(['Açıkta kalan problem', note.problem.trim()])
  if (note.firstStep.trim()) rows.push(['Yarın atacağım ilk adım', note.firstStep.trim()])
  if (note.alarm || note.alarmSentence.trim()) {
    const answer = note.alarm === 'yes' ? 'Evet' : note.alarm === 'no' ? 'Hayır' : ''
    const sentence = note.alarmSentence.trim() ? `“${note.alarmSentence.trim()}”` : ''
    rows.push(['Alarm çaldı mı', [answer, sentence].filter(Boolean).join(' · ')])
  }

  if (!rows.length) return <p className="text-[15px] text-muted">Kutular boş bırakılmış.</p>

  return (
    <dl className="space-y-3.5">
      {rows.map(([label, value]) => (
        <div key={label}>
          <dt className="text-[13px] font-medium text-muted">{label}</dt>
          <dd className="mt-0.5 text-[16px] leading-snug whitespace-pre-wrap">{value}</dd>
        </div>
      ))}
    </dl>
  )
}
