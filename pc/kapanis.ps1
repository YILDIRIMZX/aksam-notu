# Akşam Notu: bilgisayar kapanırken (olay 1074) ya da uykuya geçerken (olay 506) çalışır
# ve GitHub'dan hatırlatmayı göndermesini ister.
# Asıl "günde bir kez" kuralı GitHub'daki iştedir; buradaki kontroller yalnızca boşuna istek atmamak için.
param([switch]$Test, [string]$EventId = '')

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:ProgramData 'AksamNotu'
$log = Join-Path $dir 'gunluk.txt'
$what = switch ($EventId) { '1074' { 'Kapanış' } '506' { 'Uyku' } default { 'Tetikleme' } }

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
    if ($now.Hour -lt $cfg.startHour -and $now.Hour -ge 5) { Write-Log "$what $($cfg.startHour):00'dan önce, istek yok."; exit 0 }
    if ((Test-Path $lastFile) -and (Get-Content $lastFile -Raw).Trim() -eq $evening) { Write-Log "$what`: bu akşam zaten istendi."; exit 0 }
  }

  Add-Type -AssemblyName System.Security
  $sealed = [IO.File]::ReadAllBytes((Join-Path $dir 'token.dat'))
  $token = [Text.Encoding]::UTF8.GetString(
    [Security.Cryptography.ProtectedData]::Unprotect($sealed, $null, [Security.Cryptography.DataProtectionScope]::LocalMachine))

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $body = @{ ref = 'main'; inputs = @{ source = 'pc'; test = $(if ($Test) { 'true' } else { 'false' }) } } | ConvertTo-Json -Compress
  $request = @{
    Method      = 'Post'
    Uri         = "https://api.github.com/repos/$($cfg.repo)/actions/workflows/reminder.yml/dispatches"
    Headers     = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'aksam-notu' }
    Body        = $body
    ContentType = 'application/json'
    TimeoutSec  = 8
  }

  # Uykuya geçerken Wi-Fi bir anlığına kopabilir; birkaç kez dener.
  for ($try = 1; ; $try++) {
    try { Invoke-RestMethod @request | Out-Null; break }
    catch {
      $code = $_.Exception.Response.StatusCode.value__
      if ($code -in 401, 403, 404, 422 -or $try -ge 4) { throw }
      Start-Sleep -Seconds (5 * $try)
    }
  }

  if (-not $Test) { Set-Content -Path $lastFile -Value $evening }
  Write-Log $(if ($Test) { 'Test isteği gönderildi.' } else { "$what`: hatırlatma istendi ($evening)." })
} catch {
  $message = $_.Exception.Message
  $status = $_.Exception.Response.StatusCode.value__
  if ($status -eq 403) {
    $message = "GitHub izin vermedi (403). Token ayarlarında iki şeye bak: Repository access > Only select repositories altında $($cfg.repo) seçili olmalı ve Permissions > Repositories > Actions 'Read and write' olmalı."
  } elseif ($status -eq 401) {
    $message = 'GitHub token''ı tanımadı (401): token yanlış kopyalanmış ya da süresi dolmuş. kur.ps1 ile yenisini gir.'
  }
  Write-Log "$what`: hata: $message"
  if ($Test) { Write-Host $message -ForegroundColor Red; exit 1 }
}
