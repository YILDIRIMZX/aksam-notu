# Akşam Notu: bilgisayar kapanırken çalışır (Windows olay kaydı 1074) ve GitHub'dan hatırlatmayı göndermesini ister.
# Asıl "günde bir kez" kuralı GitHub'daki iştedir; buradaki kontroller yalnızca boşuna istek atmamak için.
param([switch]$Test)

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:ProgramData 'AksamNotu'
$log = Join-Path $dir 'gunluk.txt'

function Write-Log($text) {
  Add-Content -Path $log -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $text) -Encoding UTF8
}

try {
  $cfg = Get-Content (Join-Path $dir 'ayarlar.json') -Raw | ConvertFrom-Json
  $now = Get-Date
  # Akşam 05:00'e kadar sürer: 00:30'daki kapanış bir önceki günün akşamı sayılır.
  $evening = $now.AddHours(-5).ToString('yyyy-MM-dd')
  $lastFile = Join-Path $dir 'son-istek.txt'

  if (-not $Test) {
    if ($now.Hour -lt $cfg.startHour -and $now.Hour -ge 5) { Write-Log "Kapanış $($cfg.startHour):00'dan önce, istek yok."; exit 0 }
    if ((Test-Path $lastFile) -and (Get-Content $lastFile -Raw).Trim() -eq $evening) { Write-Log 'Bu akşam zaten istendi.'; exit 0 }
  }

  Add-Type -AssemblyName System.Security
  $sealed = [IO.File]::ReadAllBytes((Join-Path $dir 'token.dat'))
  $token = [Text.Encoding]::UTF8.GetString(
    [Security.Cryptography.ProtectedData]::Unprotect($sealed, $null, [Security.Cryptography.DataProtectionScope]::LocalMachine))

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $body = @{ ref = 'main'; inputs = @{ source = 'pc'; test = $(if ($Test) { 'true' } else { 'false' }) } } | ConvertTo-Json -Compress
  Invoke-RestMethod -Method Post `
    -Uri "https://api.github.com/repos/$($cfg.repo)/actions/workflows/reminder.yml/dispatches" `
    -Headers @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'aksam-notu' } `
    -Body $body -ContentType 'application/json' -TimeoutSec 8 | Out-Null

  if (-not $Test) { Set-Content -Path $lastFile -Value $evening }
  Write-Log $(if ($Test) { 'Test isteği gönderildi.' } else { "Hatırlatma istendi ($evening)." })
} catch {
  Write-Log "Hata: $($_.Exception.Message)"
  if ($Test) { throw }
}
