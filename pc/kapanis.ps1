# Akşam Notu: bilgisayarı bırakınca GitHub'dan akşam hatırlatmasını ister.
#   -Trigger logoff : Windows oturum kapatma betiği (her kapatma ve yeniden başlatma). Windows bitmesini bekler.
#   -Trigger sleep  : uyku olayı (kapak, güç düğmesi, Başlat > Uyku), zamanlanmış görevden.
#   -Test           : saat ve "günde bir kez" kuralı olmadan deneme isteği.
# İstek, bilgisayarın yerel saatini UTC farkıyla birlikte taşır (ör. 2026-10-09T23:19:30+03:00); GitHub kararı bu saate göre verir.
# Asıl "günde bir kez" kuralı GitHub'daki iştedir; buradaki kontroller yalnızca boşuna istek atmamak için.
param([switch]$Test, [ValidateSet('logoff', 'sleep', 'manual')][string]$Trigger = 'manual')

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:LOCALAPPDATA 'AksamNotu'
$configFile = Join-Path $dir 'ayarlar.json'
# Bu bilgisayarda Akşam Notu'nu kurmamış başka bir kullanıcı oturumu kapatıyorsa hiçbir şey yapma.
if (-not (Test-Path $configFile)) { exit 0 }

$log = Join-Path $dir 'gunluk.txt'
$what = @{ logoff = 'Kapanış'; sleep = 'Uyku'; manual = 'Elle' }[$Trigger]

function Write-Log($text) {
  Add-Content -Path $log -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'), $text) -Encoding UTF8
}

try {
  $cfg = Get-Content $configFile -Raw | ConvertFrom-Json
  $now = Get-Date
  # Akşam 05:00'e kadar sürer: 00:30'daki kapanış bir önceki günün akşamı sayılır.
  $evening = $now.AddHours(-5).ToString('yyyy-MM-dd')
  $lastFile = Join-Path $dir 'son-istek.txt'

  if (-not $Test) {
    if ($now.Hour -lt $cfg.startHour -and $now.Hour -ge 5) { exit 0 }
    if ((Test-Path $lastFile) -and (Get-Content $lastFile -Raw).Trim() -eq $evening) { Write-Log "$what`: bu akşam zaten istendi."; exit 0 }
  }

  Add-Type -AssemblyName System.Security
  $sealed = [IO.File]::ReadAllBytes((Join-Path $dir 'token.dat'))
  $token = [Text.Encoding]::UTF8.GetString(
    [Security.Cryptography.ProtectedData]::Unprotect($sealed, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser))

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $inputs = @{
    source = 'pc'
    at     = $now.ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture)
    test   = $(if ($Test) { 'true' } else { 'false' })
  }
  $request = @{
    Method      = 'Post'
    Uri         = "https://api.github.com/repos/$($cfg.repo)/actions/workflows/reminder.yml/dispatches"
    Headers     = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'aksam-notu' }
    Body        = (@{ ref = 'main'; inputs = $inputs } | ConvertTo-Json -Compress)
    ContentType = 'application/json'
    TimeoutSec  = 6
  }

  # Kapanışta Windows bekler ama kapanışı uzatmamak için az dener; uykuda Wi-Fi bir anlığına kopabilir, biraz daha dener.
  $tries = if ($Trigger -eq 'logoff') { 2 } else { 4 }
  for ($try = 1; ; $try++) {
    try { Invoke-RestMethod @request | Out-Null; break }
    catch {
      $code = $_.Exception.Response.StatusCode.value__
      if ($code -in 401, 403, 404, 422 -or $try -ge $tries) { throw }
      Start-Sleep -Seconds (2 * $try)
    }
  }

  if (-not $Test) { Set-Content -Path $lastFile -Value $evening }
  Write-Log $(if ($Test) { "Test isteği gönderildi ($($inputs.at))." } else { "$what`: hatırlatma istendi ($($inputs.at))." })
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
