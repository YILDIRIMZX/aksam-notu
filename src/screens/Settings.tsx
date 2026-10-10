import { ArrowSquareOut, BellRinging, Copy, DownloadSimple, Trash } from '@phosphor-icons/react'
import { useEffect, useState } from 'react'
import config from '../../push.config.json'
import { deleteAllNotes, downloadBackup } from '../lib/notes'
import { currentSubscription, pushState, showTestNotification, subscribe, unsubscribe, type PushState } from '../lib/push'
import { Button, Card, Page, cx, fieldClass } from '../ui'

const secretsUrl = `https://github.com/${config.repo}/settings/secrets/actions`

export default function Settings({ onBack }: { onBack: () => void }) {
  const [state, setState] = useState<PushState | null>(null)
  const [code, setCode] = useState<string | null>(null)
  const [copied, setCopied] = useState(false)
  const [error, setError] = useState('')
  const [wipeState, setWipeState] = useState<'idle' | 'confirm' | 'done'>('idle')

  useEffect(() => {
    pushState().then(async (s) => {
      setState(s)
      if (s === 'on') setCode(await currentSubscription())
    })
  }, [])

  async function enable() {
    setError('')
    try {
      setCode(await subscribe())
      setState('on')
    } catch (e) {
      setState(await pushState())
      setError(
        (e as Error).message === 'permission'
          ? 'İzin verilmedi. iPhone Ayarlar > Bildirimler > Akşam Notu bölümünden açabilirsin.'
          : 'Bildirim açılamadı. Bir süre sonra yeniden dene.',
      )
    }
  }

  // Two taps: the first asks, the second deletes. The question resets after a few seconds.
  async function wipe() {
    if (wipeState !== 'confirm') {
      setWipeState('confirm')
      setTimeout(() => setWipeState((s) => (s === 'confirm' ? 'idle' : s)), 5000)
      return
    }
    await deleteAllNotes()
    setWipeState('done')
  }

  async function disable() {
    await unsubscribe()
    setCode(null)
    setState('off')
  }

  async function copy() {
    if (!code) return
    await navigator.clipboard.writeText(code)
    setCopied(true)
    setTimeout(() => setCopied(false), 2000)
  }

  return (
    <Page title="Bildirim" onBack={onBack}>
      <Card>
        <p className="text-[15.5px] leading-relaxed">
          Bilgisayarı 21:00'den sonra kapatınca, yeniden başlatınca ya da uykuya alınca (kapak); hiçbiri olmazsa 22:00 civarında, günde en fazla bir kez şu hatırlatma gelir:
        </p>
        <div className="mt-3 rounded-field bg-accent-soft px-4 py-3 text-[15px] leading-snug text-accent-deep">
          <p className="font-semibold">{config.reminder.title}</p>
          <p>{config.reminder.body}</p>
        </div>

        <div className="mt-5">
          {state === 'needs-install' && (
            <p className="text-[15px] text-muted">
              iPhone'da bildirim için önce Safari'de <b className="text-ink">Paylaş &gt; Ana Ekrana Ekle</b> ile uygulamayı ekle, sonra
              ana ekrandaki simgeden aç.
            </p>
          )}
          {state === 'unsupported' && <p className="text-[15px] text-muted">Bu tarayıcı bildirimleri desteklemiyor.</p>}
          {state === 'denied' && (
            <p className="text-[15px] text-muted">
              Bildirim izni kapalı. Telefonda Ayarlar &gt; Bildirimler &gt; Akşam Notu bölümünden, bilgisayarda tarayıcının site
              ayarlarından açabilirsin.
            </p>
          )}
          {state === 'off' && (
            <Button onClick={enable} className="w-full">
              <BellRinging size={18} />
              Bildirimleri aç
            </Button>
          )}
          {state === 'on' && (
            <div className="flex gap-2">
              <Button variant="secondary" onClick={showTestNotification} className="flex-1">
                Görünümü dene
              </Button>
              <Button variant="secondary" onClick={disable} className="flex-1">
                Kapat
              </Button>
            </div>
          )}
          {error && <p className="mt-3 text-[14.5px] text-muted">{error}</p>}
        </div>
      </Card>

      {state === 'on' && code && (
        <Card className="mt-4">
          <h2 className="text-[17px] font-[650]">Kurulum kodu</h2>
          <p className="mt-1 mb-3 text-[14.5px] leading-relaxed text-muted">
            Bu kodu bir kez GitHub'da <b className="text-ink">PUSH_SUBSCRIPTIONS</b> adlı gizli değere yapıştır. Bildirimi kapatıp yeniden
            açarsan kod değişir, yenisini yapıştırman gerekir.
          </p>
          <textarea readOnly value={code} rows={4} className={cx(fieldClass, 'resize-none font-mono text-[12px] break-all')} />
          <div className="mt-3 flex gap-2">
            <Button onClick={copy} className="flex-1">
              <Copy size={18} />
              {copied ? 'Kopyalandı' : 'Kopyala'}
            </Button>
            <a
              href={secretsUrl}
              target="_blank"
              rel="noreferrer"
              className="inline-flex h-12 flex-1 items-center justify-center gap-2 rounded-full bg-surface-2 text-[15.5px] font-medium"
            >
              GitHub
              <ArrowSquareOut size={18} />
            </a>
          </div>
        </Card>
      )}

      <Card className="mt-4">
        <h2 className="text-[17px] font-[650]">Notların</h2>
        <p className="mt-1 mb-3 text-[14.5px] leading-relaxed text-muted">
          Notlar yalnızca bu cihazda durur, hiçbir sunucuya gönderilmez. Yedek dosyası şifresizdir, güvenli bir yerde sakla.
        </p>
        <div className="flex gap-2">
          <Button variant="secondary" onClick={downloadBackup} className="flex-1">
            <DownloadSimple size={18} />
            Yedeği indir
          </Button>
          <Button variant="secondary" onClick={wipe} className="flex-1">
            <Trash size={18} />
            {wipeState === 'confirm' ? 'Emin misin?' : wipeState === 'done' ? 'Silindi' : 'Tümünü sil'}
          </Button>
        </div>
        {wipeState === 'confirm' && (
          <p className="mt-2 text-[14px] text-muted">Tüm notlar bu cihazdan kalıcı olarak silinir. Onaylamak için yeniden dokun.</p>
        )}
      </Card>

      <p className="mt-6 text-center text-[13px] text-muted">
        Akşam Notu, <a href="https://github.com/YILDIRIMZX/Piskolojik-Destek-Uygulamas-" className="text-accent">İçgörü</a>'nün
        yardımcı uygulamasıdır.
      </p>
    </Page>
  )
}
