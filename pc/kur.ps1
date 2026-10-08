# Akşam Notu: bilgisayar tarafının tek seferlik kurulumu.
# Çalıştırmak için: sağ tık > "PowerShell ile çalıştır" ya da
#   powershell -ExecutionPolicy Bypass -File pc\kur.ps1
param(
  [string]$Repo = 'YILDIRIMZX/aksam-notu',
  [ValidateRange(0, 23)][int]$StartHour = 21
)

$ErrorActionPreference = 'Stop'
$taskName = 'Akşam Notu'

# Kapanışta görevin güvenle çalışması için SYSTEM hesabıyla kurulur; bunun için yönetici izni gerekir.
$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @(
    '-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$PSCommandPath`"", '-Repo', $Repo, '-StartHour', $StartHour)
  exit
}

$dir = Join-Path $env:ProgramData 'AksamNotu'
New-Item -ItemType Directory -Force $dir | Out-Null
# Klasörü yalnızca SYSTEM ve yöneticiler okuyabilsin: içinde GitHub anahtarı duruyor.
icacls $dir /inheritance:r /grant:r '*S-1-5-18:(OI)(CI)F' '*S-1-5-32-544:(OI)(CI)F' | Out-Null

Copy-Item (Join-Path $PSScriptRoot 'kapanis.ps1') $dir -Force
@{ repo = $Repo; startHour = $StartHour } | ConvertTo-Json | Set-Content (Join-Path $dir 'ayarlar.json') -Encoding UTF8

$tokenFile = Join-Path $dir 'token.dat'
# Tek soru: yapıştırılan değer yeni token olur, boş Enter kayıtlı olanı korur. Yazılan hiçbir şey ekranda görünmez.
$prompt = if (Test-Path $tokenFile) {
  'GitHub token''ını yapıştır ve Enter (kayıtlı token''ı korumak için yalnızca Enter). Yazarken görünmez'
} else {
  'GitHub token''ını yapıştır ve Enter. Yazarken görünmez'
}
$plain = [Net.NetworkCredential]::new('', (Read-Host $prompt -AsSecureString)).Password.Trim()
if (-not $plain -and -not (Test-Path $tokenFile)) { throw 'Token boş.' }
if ($plain) {
  if ($plain -notmatch '^(github_pat_|ghp_)') { Write-Host 'Uyarı: bu bir GitHub token''ına benzemiyor (github_pat_ ile başlamalı).' -ForegroundColor Yellow }
  Add-Type -AssemblyName System.Security
  $sealed = [Security.Cryptography.ProtectedData]::Protect(
    [Text.Encoding]::UTF8.GetBytes($plain), $null, [Security.Cryptography.DataProtectionScope]::LocalMachine)
  [IO.File]::WriteAllBytes($tokenFile, $sealed)
  $plain = $null
}

# Tetikleyiciler:
# - User32 1074: kapatma ya da yeniden başlatma başlıyor.
# - Kernel-Power 506: Modern Bekleme'ye (uyku) giriliyor. Yalnızca kullanıcının uyuttuğu durumlar sayılır:
#   15 kapak kapandı, 1 güç düğmesi, 14 uyku düğmesi, 20 Başlat > Uyku. Boşta kalınca ekranın kapanması (12) sayılmaz.
#   Modern Bekleme'de ağ bağlı kalır, istek uyku sırasında da gider.
$query = @(
  "*[System[Provider[@Name='User32'] and EventID=1074]]"
  "*[System[Provider[@Name='Microsoft-Windows-Kernel-Power'] and EventID=506] and EventData[Data[@Name='Reason']=15 or Data[@Name='Reason']=1 or Data[@Name='Reason']=14 or Data[@Name='Reason']=20]]"
) | ForEach-Object { "<Select Path='System'>$_</Select>" }
$subscription = [Security.SecurityElement]::Escape("<QueryList><Query Id='0' Path='System'>$($query -join '')</Query></QueryList>")

$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.4" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Akşam Notu: bilgisayar kapanırken ya da uykuya geçerken telefona akşam hatırlatmasını ister.</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Subscription>$subscription</Subscription>
      <ValueQueries>
        <Value name="EventID">Event/System/EventID</Value>
      </ValueQueries>
    </EventTrigger>
  </Triggers>
  <Principals>
    <Principal id="Author">
      <UserId>S-1-5-18</UserId>
      <RunLevel>HighestAvailable</RunLevel>
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
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -NonInteractive -WindowStyle Hidden -ExecutionPolicy Bypass -File "$dir\kapanis.ps1" -EventId `$(EventID)</Arguments>
    </Exec>
  </Actions>
</Task>
"@
Register-ScheduledTask -TaskName $taskName -Xml $xml -Force | Out-Null

Write-Host ''
Write-Host "Kuruldu. Bilgisayar $($StartHour):00'dan sonra kapanınca ya da uykuya geçince (kapak kapanınca) telefona hatırlatma gidecek." -ForegroundColor Green
Write-Host "Kayıtlar: $dir\gunluk.txt"
if ((Read-Host 'Şimdi bir test bildirimi göndereyim mi? (E/H)') -eq 'E') {
  $global:LASTEXITCODE = 0
  & (Join-Path $dir 'kapanis.ps1') -Test
  if ($LASTEXITCODE -eq 1) { exit 1 }
  Write-Host 'Test isteği GitHub''a gitti. Bildirim 10-60 saniye içinde telefona gelir.' -ForegroundColor Green
}
