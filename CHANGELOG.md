# Changelog / Sürüm notları

Every update is listed here with what changed and why. Newest first. Each entry is written in English and Turkish.

Her güncelleme, neyin neden değiştiğiyle birlikte burada listelenir. En yenisi en üstte. Her kayıt İngilizce ve Türkçe yazılmıştır.

---

## 1.1.1 (2026-10-08)

**EN.** Fixes from the first real setup on Windows.
- **One token prompt.** Setup used to ask "type E to change the token" and only then asked for the token. A token pasted into the first question was silently ignored, and the old token kept being used. There is now a single prompt: paste a new token, or press Enter to keep the saved one. Nothing typed is shown on screen.
- **Clear permission errors.** A 403 from GitHub now says exactly what to check (the repository is selected and Actions is "Read and write"), and 401 says the token is wrong or expired. A failed test no longer prints "sent".

**TR.** Windows'taki ilk gerçek kurulumdan çıkan düzeltmeler.
- **Tek token sorusu.** Kurulum önce "token'ı değiştirmek için E yaz" diye soruyor, token'ı ancak ondan sonra istiyordu. İlk soruya yapıştırılan token sessizce yok sayılıyor ve eski token kullanılmaya devam ediyordu. Artık tek soru var: yeni token'ı yapıştır ya da kayıtlı olanı korumak için Enter'a bas. Yazılan hiçbir şey ekranda görünmüyor.
- **Anlaşılır izin hataları.** GitHub'dan gelen 403 artık neye bakılacağını tam olarak söylüyor (repo seçili mi, Actions "Read and write" mı); 401 ise token'ın yanlış ya da süresinin dolmuş olduğunu söylüyor. Başarısız bir test artık "gitti" yazmıyor.

## 1.1.0 (2026-10-08)

**EN.** Sleep now counts as leaving the computer. The user often closes the laptop lid instead of shutting down, and that evening went unnoticed.
- The Windows task also listens for event 506 (entering Modern Standby), but only when the user starts it: closing the lid, the power or sleep button, or Start > Sleep. The screen turning off after idle time does not count, so sitting nearby with the phone does not trigger a reminder.
- Modern Standby keeps the network connected, so the request goes out while the laptop sleeps. If the connection drops for a moment, the request is retried a few times.
- The log now says whether a shutdown or sleep triggered the request.

**TR.** Uyku da artık bilgisayarı bırakmak sayılıyor. Kullanıcı çoğu zaman bilgisayarı kapatmak yerine laptopun kapağını indiriyor ve o akşam fark edilmiyordu.
- Windows görevi 506 olayını da (Modern Bekleme'ye giriş) dinliyor, ama yalnızca kullanıcı başlattığında: kapağı kapatmak, güç ya da uyku düğmesi, Başlat > Uyku. Boşta kalınca ekranın kapanması sayılmıyor; yani bilgisayarın yanında telefona bakarken hatırlatma gelmiyor.
- Modern Bekleme ağı bağlı tuttuğu için istek laptop uyurken de gidiyor. Bağlantı bir anlığına koparsa istek birkaç kez yeniden deneniyor.
- Kayıt dosyası artık isteği kapanışın mı uykunun mu tetiklediğini yazıyor.

## 1.0.0 (2026-10-08)

**EN.** First release. Built from a between-session assignment: a very simple evening note with a single trigger, kept free of streaks, scores and blame.
- **Three optional boxes:** open problem, first step tomorrow, and whether today's alarm went off (yes / no, with an optional sentence). Notes are stored by date on the device, and last night's note is shown first in the morning.
- **Shutdown reminder:** a Windows scheduled task notices a shutdown after 21:00 and asks GitHub Actions to send a Web Push reminder to the phone.
- **22:00 safety net:** if no reminder went out by 22:00, the scheduled workflow sends it, even when the computer was never switched on. The user asked for the reminder to be guaranteed every evening.
- **Once a day:** a single workflow sends every reminder and records the date, so a shutdown and the 22:00 run can never both send.
- Companion app to İçgörü, sharing its look.

**TR.** İlk sürüm. Seanslar arası bir ödevden doğdu: tek tetikleyicili, seri, puan ve suçlama içermeyen çok sade bir akşam notu.
- **İsteğe bağlı üç kutu:** açıkta kalan problem, yarın atacağım ilk adım ve bugün alarmın çalıp çalmadığı (evet / hayır, isteğe bağlı cümleyle). Notlar cihazda tarihle saklanır, sabah önce dün akşamki not gösterilir.
- **Kapanış hatırlatması:** bir Windows zamanlanmış görevi 21:00'den sonraki kapanışı fark eder ve GitHub Actions'tan telefona Web Push hatırlatması göndermesini ister.
- **22:00 güvencesi:** 22:00'ye kadar hatırlatma gitmediyse, bilgisayar hiç açılmamış olsa bile zamanlanmış iş gönderir. Kullanıcı hatırlatmanın her akşam garanti gelmesini istedi.
- **Günde bir kez:** tüm hatırlatmaları tek bir iş gönderir ve tarihi kaydeder; bir kapanış ile 22:00 çalışması asla ikisi birden göndermez.
- İçgörü'nün yardımcı uygulamasıdır ve onunla aynı görünümü paylaşır.
