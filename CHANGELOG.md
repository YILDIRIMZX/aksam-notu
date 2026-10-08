# Changelog / Sürüm notları

Every update is listed here with what changed and why. Newest first. Each entry is written in English and Turkish.

Her güncelleme, neyin neden değiştiğiyle birlikte burada listelenir. En yenisi en üstte. Her kayıt İngilizce ve Türkçe yazılmıştır.

---

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
