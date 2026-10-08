import { useEffect, useState } from 'react'
import { allNotes, formatDay, type Note } from '../lib/notes'
import { Card, Page } from '../ui'
import NoteView from './NoteView'

export default function History({ onBack }: { onBack: () => void }) {
  const [notes, setNotes] = useState<Note[] | null>(null)

  useEffect(() => {
    void allNotes().then(setNotes)
  }, [])

  return (
    <Page title="Geçmiş" onBack={onBack}>
      {notes?.length === 0 && <p className="text-[15.5px] text-muted">Henüz kaydedilmiş not yok.</p>}
      <div className="space-y-3">
        {notes?.map((n) => (
          <Card key={n.date}>
            <p className="mb-3 text-[14px] font-semibold text-accent">{formatDay(n.date)}</p>
            <NoteView note={n} />
          </Card>
        ))}
      </div>
    </Page>
  )
}
