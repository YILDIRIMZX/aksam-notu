# Akşam Notu: bilgisayar tarafını kaldırır (oturum kapatma betiği, görev, ayarlar ve kayıtlı GitHub token'ı).
$ErrorActionPreference = 'Stop'

$admin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
  [Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $admin) {
  Start-Process powershell.exe -Verb RunAs -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-NoExit', '-File', "`"$PSCommandPath`"")
  exit
}

# Oturum kapatma betiği: yalnızca Akşam Notu girişlerini çıkar, diğerlerine dokunma.
$gp = Join-Path $env:SystemRoot 'System32\GroupPolicy'
$ini = Join-Path $gp 'User\Scripts\scripts.ini'
if (Test-Path $ini) {
  $sections = [ordered]@{}; $current = $null
  foreach ($line in Get-Content $ini -Encoding Unicode) {
    if ($line -match '^\s*\[(.+)\]\s*$') { $current = $Matches[1]; $sections[$current] = [ordered]@{}; continue }
    if ($current -and $line -match '^(\d+)(CmdLine|Parameters)=(.*)$') {
      if (-not $sections[$current].Contains($Matches[1])) { $sections[$current][$Matches[1]] = @{ CmdLine = ''; Parameters = '' } }
      $sections[$current][$Matches[1]][$Matches[2]] = $Matches[3]
    }
  }
  $out = foreach ($name in @($sections.Keys)) {
    $entries = @($sections[$name].Values | Where-Object { "$($_.CmdLine) $($_.Parameters)" -notmatch 'AksamNotu' })
    "[$name]"
    for ($i = 0; $i -lt $entries.Count; $i++) { "${i}CmdLine=$($entries[$i].CmdLine)"; "${i}Parameters=$($entries[$i].Parameters)" }
  }
  (Get-Item $ini -Force).Attributes = 'Normal'
  Set-Content -Path $ini -Value $out -Encoding Unicode
  $gpt = Join-Path $gp 'gpt.ini'
  if (Test-Path $gpt) {
    $lines = @(Get-Content $gpt)
    $lines = $lines | ForEach-Object {
      if ($_ -like 'Version=*') { $v = [int64]($_ -replace '^Version=', ''); "Version=$(((($v -shr 16) + 1) -shl 16) + ($v -band 0xFFFF))" } else { $_ }
    }
    Set-Content -Path $gpt -Value $lines -Encoding Ascii
  }
  gpupdate /target:user /force | Out-Null
}

Unregister-ScheduledTask -TaskName 'Akşam Notu' -Confirm:$false -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force (Join-Path $env:ProgramData 'AksamNotu'), (Join-Path $env:LOCALAPPDATA 'AksamNotu') -ErrorAction SilentlyContinue
Write-Host 'Akşam Notu bilgisayardan kaldırıldı. GitHub token''ını GitHub ayarlarından da silmeyi unutma.' -ForegroundColor Green
