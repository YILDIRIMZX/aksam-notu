# Akşam Notu: bilgisayarı bırakınca GitHub'dan akşam hatırlatmasını ister.
#   -Trigger watch  : SYSTEM hesabıyla açılıştan itibaren çalışan izleyici. Uyku olayını (Kernel-Power 506) anında yakalar.
#                     Modern Bekleme'de kullanıcı oturumundaki programlar uykunun ilk saniyelerinde dondurulur;
#                     sistem süreçleri dondurulmaz, bu yüzden istek uyku sırasında gidebilir.
#   -Trigger logoff : Windows oturum kapatma betiği (her kapatma ve yeniden başlatma). Windows bitmesini bekler.
#   -Test           : saat ve "günde bir kez" kuralı olmadan deneme isteği (kullanıcı hesabıyla).
# İstek, bilgisayarın yerel saatini UTC farkıyla birlikte taşır (ör. 2026-10-09T23:19:30+03:00); GitHub kararı bu saate göre verir.
# Asıl "günde bir kez" kuralı GitHub'daki iştedir; buradaki kontroller yalnızca boşuna istek atmamak için.
param([switch]$Test, [ValidateSet('watch', 'logoff', 'manual')][string]$Trigger = 'manual')

$ErrorActionPreference = 'Stop'
$shared = Join-Path $env:ProgramData 'AksamNotu'

# İzleyici SYSTEM olarak çalışır ve makine şifreli token'ı yalnızca SYSTEM ile yöneticilerin okuyabildiği klasörden okur.
# Diğer kullanımlar kullanıcının kendi klasörünü ve kullanıcıya şifreli token'ı kullanır.
if ($Trigger -eq 'watch') {
  $dir = Join-Path $shared 'gizli'
  $scope = [Security.Cryptography.DataProtectionScope]::LocalMachine
  $log = Join-Path $shared 'gunluk.txt'   # kişisel bilgi ya da sır içermez; kullanıcı okuyabilsin
} else {
  $dir = Join-Path $env:LOCALAPPDATA 'AksamNotu'
  $scope = [Security.Cryptography.DataProtectionScope]::CurrentUser
  $log = Join-Path $dir 'gunluk.txt'
}
$configFile = Join-Path $dir 'ayarlar.json'
# Bu bilgisayarda Akşam Notu'nu kurmamış başka bir kullanıcı oturumu kapatıyorsa hiçbir şey yapma.
if (-not (Test-Path $configFile)) { exit 0 }
$lastFile = Join-Path $dir 'son-istek.txt'
Add-Type -AssemblyName System.Security

function Write-Log($text) {
  Add-Content -Path $log -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'), $text) -Encoding UTF8
}

# Akşam 05:00'e kadar sürer: 00:30'daki kapanış bir önceki günün akşamı sayılır.
function Get-Evening([datetime]$at) { $at.AddHours(-5).ToString('yyyy-MM-dd') }

function Test-ShouldAsk([datetime]$at) {
  if ($at.Hour -lt $cfg.startHour -and $at.Hour -ge 5) { return $false }
  -not ((Test-Path $lastFile) -and (Get-Content $lastFile -Raw).Trim() -eq (Get-Evening $at))
}

function Get-Token {
  [Text.Encoding]::UTF8.GetString(
    [Security.Cryptography.ProtectedData]::Unprotect([IO.File]::ReadAllBytes((Join-Path $dir 'token.dat')), $null, $scope))
}

function Send-Reminder([string]$what, [datetime]$at, [string]$token, [switch]$Test, [int]$Tries = 2) {
  $inputs = @{
    source = 'pc'
    at     = $at.ToString('yyyy-MM-ddTHH:mm:sszzz', [Globalization.CultureInfo]::InvariantCulture)
    test   = $(if ($Test) { 'true' } else { 'false' })
  }
  $request = @{
    Method      = 'Post'
    Uri         = "https://api.github.com/repos/$($cfg.repo)/actions/workflows/reminder.yml/dispatches"
    Headers     = @{ Authorization = "Bearer $token"; Accept = 'application/vnd.github+json'; 'X-GitHub-Api-Version' = '2022-11-28'; 'User-Agent' = 'aksam-notu' }
    Body        = (@{ ref = 'main'; inputs = $inputs } | ConvertTo-Json -Compress)
    ContentType = 'application/json'
    TimeoutSec  = 8
  }
  try {
    for ($try = 1; ; $try++) {
      try { Invoke-RestMethod @request | Out-Null; break }
      catch {
        $code = $_.Exception.Response.StatusCode.value__
        if ($code -in 401, 403, 404, 422 -or $try -ge $Tries) { throw }
        Start-Sleep -Milliseconds (1000 * $try)
      }
    }
    if (-not $Test) { Set-Content -Path $lastFile -Value (Get-Evening $at) }
    Write-Log $(if ($Test) { "Test isteği gönderildi ($($inputs.at))." } else { "$what`: hatırlatma istendi ($($inputs.at))." })
    return $true
  } catch {
    $message = $_.Exception.Message
    $status = $_.Exception.Response.StatusCode.value__
    if ($status -eq 403) {
      $message = "GitHub izin vermedi (403). Token ayarlarında iki şeye bak: Repository access > Only select repositories altında $($cfg.repo) seçili olmalı ve Permissions > Repositories > Actions 'Read and write' olmalı."
    } elseif ($status -eq 401) {
      $message = 'GitHub token''ı tanımadı (401): token yanlış kopyalanmış ya da süresi dolmuş. kur.ps1 ile yenisini gir.'
    }
    Write-Log "$what`: hata: $message"
    if ($Test) { Write-Host $message -ForegroundColor Red }
    return $false
  }
}

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$cfg = Get-Content $configFile -Raw | ConvertFrom-Json

if ($Trigger -ne 'watch') {
  $now = Get-Date
  if (-not $Test -and -not (Test-ShouldAsk $now)) { exit 0 }
  $what = if ($Trigger -eq 'logoff') { 'Kapanış' } else { 'Elle' }
  $ok = Send-Reminder $what $now (Get-Token) -Test:$Test
  if ($Test -and -not $ok) { exit 1 }
  exit 0
}

# --- İzleyici (SYSTEM) ---
# Kullanıcının uyuttuğu durumlar (Kernel-Power 506 nedeni): 1 güç düğmesi, 11 ekranı kapatma isteği (Başlat > Uyku),
# 14 uyku düğmesi, 15 kapak, 20 uyku geçişi. Boşta kalınca ekranın kapanması (12) sayılmaz.
$userReasons = '1', '11', '14', '15', '20'
$query = [Diagnostics.Eventing.Reader.EventLogQuery]::new('System', [Diagnostics.Eventing.Reader.PathType]::LogName,
  "*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and EventID=506]]")
$watcher = [Diagnostics.Eventing.Reader.EventLogWatcher]::new($query)
Register-ObjectEvent -InputObject $watcher -EventName EventRecordWritten -SourceIdentifier AksamUyku | Out-Null
$watcher.Enabled = $true

# Uyku anında saniyeler önemli: token şimdi çözülür ve HTTPS katmanı bir istekle önceden yüklenir.
$token = Get-Token
try {
  Invoke-RestMethod -Uri "https://api.github.com/repos/$($cfg.repo)" -TimeoutSec 15 `
    -Headers @{ Authorization = "Bearer $token"; 'User-Agent' = 'aksam-notu' } | Out-Null
  Write-Log 'İzleyici başladı.'
} catch {
  Write-Log "İzleyici başladı, GitHub'a henüz ulaşılamadı: $($_.Exception.Message)"
}

while ($true) {
  $event = Wait-Event -SourceIdentifier AksamUyku
  Remove-Event -EventIdentifier $event.EventIdentifier
  try {
    $record = $event.SourceEventArgs.EventRecord
    if (-not $record) { continue }
    $reason = (([xml]$record.ToXml()).Event.EventData.Data | Where-Object Name -eq 'Reason').'#text'
    $at = $record.TimeCreated
    if ($reason -notin $userReasons -or -not (Test-ShouldAsk $at)) { continue }
    $what = if ($reason -eq '15') { 'Kapak' } else { 'Uyku' }
    [void](Send-Reminder $what $at $token -Tries 4)
  } catch {
    Write-Log "İzleyici: hata: $($_.Exception.Message)"
  }
}
