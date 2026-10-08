import { useEffect, useState } from 'react'
import History from './screens/History'
import Settings from './screens/Settings'
import Today from './screens/Today'
import { eveningKey } from './lib/notes'

type View = 'today' | 'history' | 'settings'

export default function App() {
  const [view, setView] = useState<View>('today')
  // The evening changes at 05:00. Recheck whenever the app comes back to the foreground.
  const [day, setDay] = useState(eveningKey)

  useEffect(() => {
    const refresh = () => document.visibilityState === 'visible' && setDay(eveningKey())
    document.addEventListener('visibilitychange', refresh)
    return () => document.removeEventListener('visibilitychange', refresh)
  }, [])

  useEffect(() => {
    window.scrollTo(0, 0)
  }, [view])

  if (view === 'history') return <History onBack={() => setView('today')} />
  if (view === 'settings') return <Settings onBack={() => setView('today')} />
  return <Today key={day} day={day} onOpen={setView} />
}
