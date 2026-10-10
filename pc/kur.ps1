# Akşam Notu: bilgisayar tarafının kurulumu (eski sürümden yükseltmeyi de yapar).
# Çalıştırmak için:  powershell -ExecutionPolicy Bypass -File pc\kur.ps1
# Ne kurar:
#   - Oturum kapatma betiği (yerel Grup İlkesi): her kapatma ve yeniden başlatmada çalışır, Windows bitmesini bekler.
#   - Zamanlanmış görev: kapak kapanınca, güç ya da uyku düğmesinde, Başlat > Uyku'da çalışır.
#   - Token senin kullanıcı klasöründe, yalnızca senin hesabının çözebildiği şifreyle (DPAPI CurrentUser) saklanır.
param(
  [string]$Repo = 'YILDIRIMZX/aksam-notu',
  [ValidateRange(0, 23)][int]$StartHour = 21,
  [string]$UserSid = ''
)

$ErrorActionPreference = 'Stop'
$taskName = 'Akşam Notu'
$me = [Security.Principal.WindowsIdentity]::GetCurrent()

# Grup İlkesi ve ProgramData için yönetici izni gerekir. Yükseltilmiş pencere aynı kullanıcı olmalı,
# yoksa token ve ayarlar başka bir hesabın klasörüne yazılır.
$admin = ([Security.Principal.WindowsPrincipal]$me).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$PSCommandPath`"",
    '-Repo', $Repo, '-StartHour', $StartHour, '-UserSid', $me.User.Value)
  exit
}
if ($UserSid -and $UserSid -ne $me.User.Value) {
  throw 'Yönetici penceresi başka bir hesapla açıldı. Akşam Notu''nu kullanacağın hesabın yönetici olması gerekir.'
}

$shared = Join-Path $env:ProgramData 'AksamNotu'   # yalnızca betik: herkes okur, yöneticiler değiştirir
$userDir = Join-Path $env:LOCALAPPDATA 'AksamNotu'  # ayarlar, token, kayıtlar: yalnızca bu kullanıcı
$script = Join-Path $shared 'kapanis.ps1'
Add-Type -AssemblyName System.Security

# --- Eski sürümden (SYSTEM görevi, makine şifreli token) yükseltme ---
$oldToken = Join-Path $shared 'token.dat'
$migrated = $null
if (Test-Path $oldToken) {
  try {
    $migrated = [Security.Cryptography.ProtectedData]::Unprotect(
      [IO.File]::ReadAllBytes($oldToken), $null, [Security.Cryptography.DataProtectionScope]::LocalMachine)
  } catch { $migrated = $null }
}
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue

# --- Dosyalar ---
New-Item -ItemType Directory -Force $shared, $userDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'kapanis.ps1') $script -Force
Get-ChildItem $shared -File | Where-Object Name -ne 'kapanis.ps1' | Remove-Item -Force
# Oturum kapanırken senin hesabınla çalışan betiği yalnızca yöneticiler değiştirebilsin.
icacls $shared /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' '*S-1-5-32-545:(OI)(CI)RX' | Out-Null

@{ repo = $Repo; startHour = $StartHour } | ConvertTo-Json | Set-Content (Join-Path $userDir 'ayarlar.json') -Encoding UTF8

$tokenFile = Join-Path $userDir 'token.dat'
function Save-Token([byte[]]$plainBytes) {
  $sealed = [Security.Cryptography.ProtectedData]::Protect($plainBytes, $null, [Security.Cryptography.DataProtectionScope]::CurrentUser)
  [IO.File]::WriteAllBytes($tokenFile, $sealed)
}
if ($migrated) { Save-Token $migrated; $migrated = $null }

$prompt = if (Test-Path $tokenFile) {
  'GitHub token''ını yapıştır ve Enter (kayıtlı token''ı korumak için yalnızca Enter). Yazarken görünmez'
} else {
  'GitHub token''ını yapıştır ve Enter. Yazarken görünmez'
}
$plain = [Net.NetworkCredential]::new('', (Read-Host $prompt -AsSecureString)).Password.Trim()
if (-not $plain -and -not (Test-Path $tokenFile)) { throw 'Token boş.' }
if ($plain) {
  if ($plain -notmatch '^(github_pat_|ghp_)') { Write-Host 'Uyarı: bu bir GitHub token''ına benzemiyor (github_pat_ ile başlamalı).' -ForegroundColor Yellow }
  Save-Token ([Text.Encoding]::UTF8.GetBytes($plain))
  $plain = $null
}

# --- Oturum kapatma betiği (yerel Grup İlkesi, Kullanıcı > Komut dosyaları > Oturumu kapatma) ---
function Set-LogoffScript([bool]$Enable) {
  $gp = Join-Path $env:SystemRoot 'System32\GroupPolicy'
  $scriptsDir = Join-Path $gp 'User\Scripts'
  New-Item -ItemType Directory -Force (Join-Path $scriptsDir 'Logoff'), (Join-Path $scriptsDir 'Logon') | Out-Null
  $ini = Join-Path $scriptsDir 'scripts.ini'

  # Var olan girişleri koru, yalnızca Akşam Notu'nunkileri değiştir.
  $sections = [ordered]@{}
  $current = $null
  if (Test-Path $ini) {
    foreach ($line in Get-Content $ini -Encoding Unicode) {
      if ($line -match '^\s*\[(.+)\]\s*$') { $current = $Matches[1]; $sections[$current] = [ordered]@{}; continue }
      if ($current -and $line -match '^(\d+)(CmdLine|Parameters)=(.*)$') {
        if (-not $sections[$current].Contains($Matches[1])) { $sections[$current][$Matches[1]] = @{ CmdLine = ''; Parameters = '' } }
        $sections[$current][$Matches[1]][$Matches[2]] = $Matches[3]
      }
    }
  }
  if (-not $sections.Contains('Logoff')) { $sections['Logoff'] = [ordered]@{} }
  $out = foreach ($name in @($sections.Keys)) {
    $entries = @($sections[$name].Values | Where-Object { "$($_.CmdLine) $($_.Parameters)" -notmatch 'AksamNotu' })
    if ($name -eq 'Logoff' -and $Enable) {
      $entries += @{ CmdLine = 'powershell.exe'; Parameters = "-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`" -Trigger logoff" }
    }
    "[$name]"
    for ($i = 0; $i -lt $entries.Count; $i++) { "${i}CmdLine=$($entries[$i].CmdLine)"; "${i}Parameters=$($entries[$i].Parameters)" }
  }
  Set-Content -Path $ini -Value $out -Encoding Unicode
  (Get-Item $ini -Force).Attributes = 'Hidden'

  # gpt.ini: Komut dosyaları uzantısını ekle ve kullanıcı sürümünü artır ki Windows yeni ayarı okusun.
  $gpt = Join-Path $gp 'gpt.ini'
  $lines = if (Test-Path $gpt) { @(Get-Content $gpt) } else { @('[General]') }
  $scriptsExt = '[{42B5FAAE-6536-11D2-AE5A-0000F87571E3}{40B66650-4972-11D1-A7CA-0000F87571E3}]'
  $extLine = $lines | Where-Object { $_ -like 'gPCUserExtensionNames=*' } | Select-Object -First 1
  $exts = if ($extLine) { @([regex]::Matches($extLine, '\[[^\]]+\]') | ForEach-Object Value) } else { @() }
  if ($exts -notcontains $scriptsExt) { $exts += $scriptsExt }
  $extValue = 'gPCUserExtensionNames=' + (($exts | Sort-Object) -join '')
  $verLine = $lines | Where-Object { $_ -like 'Version=*' } | Select-Object -First 1
  $ver = if ($verLine) { [int64]($verLine -replace '^Version=', '') } else { 0 }
  $newVer = ((($ver -shr 16) + 1) -shl 16) + ($ver -band 0xFFFF)
  $lines = @($lines | Where-Object { $_ -notlike 'gPCUserExtensionNames=*' -and $_ -notlike 'Version=*' })
  if ($lines -notcontains '[General]') { $lines = @('[General]') + $lines }
  $lines += $extValue, "Version=$newVer"
  Set-Content -Path $gpt -Value $lines -Encoding Ascii

  gpupdate /target:user /force | Out-Null
}
Set-LogoffScript $true

# --- Uyku görevi (senin hesabınla, pencere açmadan) ---
# Kernel-Power 506: Modern Bekleme'ye giriş. Yalnızca kullanıcının uyuttuğu durumlar sayılır:
# 15 kapak kapandı, 1 güç düğmesi, 14 uyku düğmesi, 20 Başlat > Uyku, 11 ekranı kapatma isteği (bazı bilgisayarlarda uyku menüsü ve düğmeler bunu yazar).
# Boşta kalınca ekranın kendiliğinden kapanması (12) sayılmaz.
$query = "<QueryList><Query Id='0' Path='System'><Select Path='System'>*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and EventID=506] and EventData[Data[@Name='Reason']=15 or Data[@Name='Reason']=1 or Data[@Name='Reason']=14 or Data[@Name='Reason']=20 or Data[@Name='Reason']=11]]</Select></Query></QueryList>"
$subscription = [Security.SecurityElement]::Escape($query)
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Akşam Notu: bilgisayar uykuya geçince telefona akşam hatırlatmasını ister. Kapanışı oturum kapatma betiği yakalar.</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>$subscription</Subscription>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>$($me.User.Value)</UserId>
      <LogonType>InteractiveToken</LogonType>
      <RunLevel>LeastPrivilege</RunLevel>
    </Principal>
  </Principals>
  <Settings>
    <MultipleInstancesPolicy>IgnoreNew</MultipleInstancesPolicy>
    <DisallowStartIfOnBatteries>false</DisallowStartIfOnBatteries>
    <StopIfGoingOnBatteries>false</StopIfGoingOnBatteries>
    <ExecutionTimeLimit>PT2M</ExecutionTimeLimit>
    <Priority>4</Priority>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>conhost.exe</Command>
      <Arguments>--headless powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$script" -Trigger sleep</Arguments>
    </Exec>
  </Actions>
</Task>
"@
Register-ScheduledTask -TaskName $taskName -Xml $xml -Force | Out-Null

# --- Doğrulama ---
$logoffKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Group Policy\Scripts\Logoff'
# Yalnızca Parameters okunur: Windows aynı anahtarda PowerShell'in çeviremediği bir ExecTime değeri tutuyor.
$logoffOk = Get-ChildItem $logoffKey -Recurse -ErrorAction SilentlyContinue |
  Where-Object { "$((Get-Item $_.PSPath).GetValue('Parameters'))" -match 'AksamNotu' }

Write-Host ''
Write-Host "Kuruldu. $($StartHour):00'dan sonra bilgisayarı kapatınca, yeniden başlatınca ya da uykuya alınca (kapak) telefona hatırlatma gidecek." -ForegroundColor Green
if (-not $logoffOk) { Write-Host 'Uyarı: oturum kapatma betiği henüz etkin görünmüyor. Bilgisayarı bir kez yeniden başlatınca etkinleşir.' -ForegroundColor Yellow }
Write-Host "Kayıtlar: $userDir\gunluk.txt"
if ((Read-Host 'Şimdi bir test bildirimi göndereyim mi? (E/H)') -eq 'E') {
  $global:LASTEXITCODE = 0
  & $script -Test
  if ($LASTEXITCODE -eq 1) { exit 1 }
  Write-Host 'Test isteği GitHub''a gitti. Bildirim 10-60 saniye içinde telefona gelir.' -ForegroundColor Green
}
