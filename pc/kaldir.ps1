# Akşam Notu: bilgisayar tarafını kaldırır (görev, ayarlar ve kayıtlı GitHub anahtarı).
$ErrorActionPreference = 'Stop'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$PSCommandPath`"")
  exit
}

Unregister-ScheduledTask -TaskName 'Akşam Notu' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $env:ProgramData 'AksamNotu') -ErrorAction SilentlyContinue
Write-Host 'Akşam Notu bilgisayardan kaldırıldı. GitHub anahtarını GitHub ayarlarından da silmeyi unutma.' -ForegroundColor Green
