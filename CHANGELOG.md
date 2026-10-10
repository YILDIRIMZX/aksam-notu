# Changelog / Sürüm notları

Every update is listed here with what changed and why. Newest first. Each entry is written in English and Turkish.

Her güncelleme, neyin neden değiştiğiyle birlikte burada listelenir. En yenisi en üstte. Her kayıt İngilizce ve Türkçe yazılmıştır.

---

## 1.3.1 (2026-10-10)

**EN.** Setup stopped at its final check with "Specified cast is not valid", after everything had already been installed. Windows keeps an `ExecTime` value next to the logoff script that PowerShell cannot convert, and the check read every value. It now reads only the script's parameters.

**TR.** Kurulum, her şey zaten kurulduktan sonra son kontrolde "Belirtilen atama geçerli değil" hatasıyla duruyordu. Windows oturum kapatma betiğinin yanında PowerShell'in çeviremediği bir `ExecTime` değeri tutuyor ve kontrol tüm değerleri okuyordu. Artık yalnızca betiğin parametrelerini okuyor.

## 1.3.0 (2026-10-10)

**EN.** Reminders came at the wrong time: at 02:32 and 03:12 instead of the evening, and a shutdown sent nothing.
- **No more night-time reminders.** GitHub started the 22:00 scheduled run four to five hours late. The wait step then misread the time, waited for the next evening, timed out, and the send step still ran. Now a scheduled run only sends between 22:00 and 23:30, a cancelled wait never leads to a send, and there are three scheduled runs (21:40, 22:00, 22:20) for a better chance of one starting on time.
- **The computer sends its own time.** Each request carries the computer's local time with its UTC offset (for example `2026-10-09T23:19:30+03:00`). GitHub decides by that time, not by when the request arrives, and ignores a request that waited more than 90 minutes.
- **Shutdowns are caught reliably.** Windows did not log the shutdown event on these evenings, and the last second before power-off is too short for a network request. Shutdown and restart are now caught by a logoff script (local Group Policy), which Windows runs on every shutdown and waits for. Sleep is still caught by the event task, which now runs under the user's own account.
- **Token stored per user.** The token is now encrypted for the user's Windows account and kept in the user's profile. Setup upgrades an earlier installation and keeps its token.
- The decision rules moved into `.github/push/decide.mjs`, with tests in `decide.test.mjs` covering the late-schedule case.

**TR.** Hatırlatmalar yanlış saatte geliyordu: akşam yerine 02:32'de ve 03:12'de; bilgisayarı kapatmak ise hiçbir şey göndermiyordu.
- **Artık gece hatırlatması yok.** GitHub 22:00 zamanlanmış işini dört beş saat geç başlattı. Bekleme adımı saati yanlış okuyup bir sonraki akşamı beklemeye başladı, zaman aşımına uğradı ve gönderme adımı yine de çalıştı. Artık zamanlanmış bir çalışma yalnızca 22:00 ile 23:30 arasında gönderiyor, iptal edilen bir bekleme asla gönderime yol açmıyor ve birinin zamanında başlaması için üç zamanlanmış çalışma var (21:40, 22:00, 22:20).
- **Bilgisayar kendi saatini gönderiyor.** Her istek bilgisayarın yerel saatini UTC farkıyla birlikte taşıyor (ör. `2026-10-09T23:19:30+03:00`). GitHub kararı isteğin ulaştığı ana göre değil bu saate göre veriyor ve 90 dakikadan fazla bekleyen bir isteği yok sayıyor.
- **Kapanışlar güvenilir şekilde yakalanıyor.** Windows bu akşamlarda kapanış olayını yazmadı ve kapanmadan önceki son saniye bir ağ isteği için çok kısa. Kapatma ve yeniden başlatmayı artık Windows'un her kapanışta çalıştırıp bitmesini beklediği bir oturum kapatma betiği (yerel Grup İlkesi) yakalıyor. Uykuyu yine olay görevi yakalıyor; görev artık kullanıcının kendi hesabıyla çalışıyor.
- **Token kullanıcıya özel saklanıyor.** Token artık kullanıcının Windows hesabına göre şifrelenip kullanıcının profil klasöründe tutuluyor. Kurulum önceki kurulumu yükseltiyor ve token'ını koruyor.
- Karar kuralları `.github/push/decide.mjs` dosyasına taşındı; geç zamanlama durumunu da kapsayan testler `decide.test.mjs` içinde.

## 1.2.0 (2026-10-08)

**EN.** A shorter notification and privacy measures.
- **Shorter notification.** iOS already shows the app name under the title, so "Akşam Notu" appeared twice. The title is now "Yatmadan önce üç satır" and the text is shorter. The wording lives in one place (`push.config.json`) and is shared by the sender, the app and the test notification.
- **The app cannot send data anywhere.** The published page now carries a Content Security Policy that allows connections only to its own address, and links are opened without a referrer.
- **Delete all notes.** Notes can be deleted from the device with a two-tap confirmation. The backup button now says that the file is not encrypted.
- **Persistent storage.** The app asks the browser not to clear notes under storage pressure.
- **Quieter logs.** In a public repository Actions logs are visible to everyone, so the reminder workflow no longer logs who triggered it or the time.
- The documentation explains what is public and who can send notifications, and personal details were removed from earlier entries.

**TR.** Daha kısa bildirim ve gizlilik önlemleri.
- **Daha kısa bildirim.** iOS uygulamanın adını zaten başlığın altında gösterdiği için "Akşam Notu" iki kez görünüyordu. Başlık artık "Yatmadan önce üç satır", metin daha kısa. Metin tek bir yerde (`push.config.json`) duruyor; gönderici, uygulama ve deneme bildirimi aynı metni kullanıyor.
- **Uygulama hiçbir yere veri gönderemez.** Yayınlanan sayfada artık yalnızca kendi adresine bağlantıya izin veren bir İçerik Güvenlik Politikası (CSP) var; bağlantılar yönlendiren bilgisi olmadan açılıyor.
- **Tüm notları silme.** Notlar iki dokunuşluk onayla cihazdan silinebiliyor. Yedek düğmesi artık dosyanın şifresiz olduğunu söylüyor.
- **Kalıcı depolama.** Uygulama, depolama sıkışıklığında notları silmemesini tarayıcıdan istiyor.
- **Daha sessiz kayıtlar.** Herkese açık bir repoda Actions kayıtlarını herkes görebildiği için hatırlatma işi artık kimin tetiklediğini ve saati yazmıyor.
- Belgeler neyin herkese açık olduğunu ve kimin bildirim gönderebileceğini anlatıyor; önceki kayıtlardaki kişisel ayrıntılar çıkarıldı.
## 1.1.1 (2026-10-08)

**EN.** Fixes for the Windows setup.
- **One token prompt.** Setup used to ask "type E to change the token" and only then asked for the token. A token pasted into the first question was silently ignored, and the old token kept being used. There is now a single prompt: paste a new token, or press Enter to keep the saved one. Nothing typed is shown on screen.
- **Clear permission errors.** A 403 from GitHub now says exactly what to check (the repository is selected and Actions is "Read and write"), and 401 says the token is wrong or expired. A failed test no longer prints "sent".

**TR.** Windows kurulumu için düzeltmeler.
- **Tek token sorusu.** Kurulum önce "token'ı değiştirmek için E yaz" diye soruyor, token'ı ancak ondan sonra istiyordu. İlk soruya yapıştırılan token sessizce yok sayılıyor ve eski token kullanılmaya devam ediyordu. Artık tek soru var: yeni token'ı yapıştır ya da kayıtlı olanı korumak için Enter'a bas. Yazılan hiçbir şey ekranda görünmüyor.
- **Anlaşılır izin hataları.** GitHub'dan gelen 403 artık neye bakılacağını tam olarak söylüyor (repo seçili mi, Actions "Read and write" mı); 401 ise token'ın yanlış ya da süresinin dolmuş olduğunu söylüyor. Başarısız bir test artık "gitti" yazmıyor.

## 1.1.0 (2026-10-08)

**EN.** Sleep now counts as leaving the computer. Many people close the laptop lid instead of shutting down, and such evenings went unnoticed.
- The Windows task also listens for event 506 (entering Modern Standby), but only when the user starts it: closing the lid, the power or sleep button, or Start > Sleep. The screen turning off after idle time does not count, so sitting nearby with the phone does not trigger a reminder.
- Modern Standby keeps the network connected, so the request goes out while the laptop sleeps. If the connection drops for a moment, the request is retried a few times.
- The log now says whether a shutdown or sleep triggered the request.

**TR.** Uyku da artık bilgisayarı bırakmak sayılıyor. Pek çok kişi bilgisayarı kapatmak yerine laptopun kapağını indiriyor ve böyle akşamlar fark edilmiyordu.
- Windows görevi 506 olayını da (Modern Bekleme'ye giriş) dinliyor, ama yalnızca kullanıcı başlattığında: kapağı kapatmak, güç ya da uyku düğmesi, Başlat > Uyku. Boşta kalınca ekranın kapanması sayılmıyor; yani bilgisayarın yanında telefona bakarken hatırlatma gelmiyor.
- Modern Bekleme ağı bağlı tuttuğu için istek laptop uyurken de gidiyor. Bağlantı bir anlığına koparsa istek birkaç kez yeniden deneniyor.
- Kayıt dosyası artık isteği kapanışın mı uykunun mu tetiklediğini yazıyor.

## 1.0.0 (2026-10-08)

**EN.** First release. A very simple evening note with a single trigger, kept free of streaks, scores and blame.
- **Three optional boxes:** open problem, first step tomorrow, and whether today's alarm went off (yes / no, with an optional sentence). Notes are stored by date on the device, and last night's note is shown first in the morning.
- **Shutdown reminder:** a Windows scheduled task notices a shutdown after 21:00 and asks GitHub Actions to send a Web Push reminder to the phone.
- **22:00 safety net:** if no reminder went out by 22:00, the scheduled workflow sends it, even when the computer was never switched on. This way the reminder is guaranteed every evening.
- **Once a day:** a single workflow sends every reminder and records the date, so a shutdown and the 22:00 run can never both send.
- Companion app to İçgörü, sharing its look.

**TR.** İlk sürüm. Tek tetikleyicili, seri, puan ve suçlama içermeyen çok sade bir akşam notu.
- **İsteğe bağlı üç kutu:** açıkta kalan problem, yarın atacağım ilk adım ve bugün alarmın çalıp çalmadığı (evet / hayır, isteğe bağlı cümleyle). Notlar cihazda tarihle saklanır, sabah önce dün akşamki not gösterilir.
- **Kapanış hatırlatması:** bir Windows zamanlanmış görevi 21:00'den sonraki kapanışı fark eder ve GitHub Actions'tan telefona Web Push hatırlatması göndermesini ister.
- **22:00 güvencesi:** 22:00'ye kadar hatırlatma gitmediyse, bilgisayar hiç açılmamış olsa bile zamanlanmış iş gönderir. Böylece hatırlatma her akşam garanti gelir.
- **Günde bir kez:** tüm hatırlatmaları tek bir iş gönderir ve tarihi kaydeder; bir kapanış ile 22:00 çalışması asla ikisi birden göndermez.
- İçgörü'nün yardımcı uygulamasıdır ve onunla aynı görünümü paylaşır.
