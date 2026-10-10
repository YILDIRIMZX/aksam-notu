# Akşam Notu: bilgisayarı bırakınca GitHub'dan akşam hatırlatmasını ister.
#   -Trigger watch  : oturum açıkken arka planda çalışan izleyici. Windows ekranı kapatırken ya da kapak kapanırken
#                     haber verir; istek uykudan ÖNCE gider. (Modern Bekleme uykuya girince yeni program başlatmaz,
#                     bu yüzden uyku olayına bağlı bir görev ancak uyanınca çalışabilir.)
#   -Trigger logoff : Windows oturum kapatma betiği (her kapatma ve yeniden başlatma). Windows bitmesini bekler.
#   -Trigger sleep  : uyku olayına bağlı görev; izleyici bir şekilde kaçırırsa uyanınca yedek olarak çalışır.
#   -Test           : saat ve "günde bir kez" kuralı olmadan deneme isteği.
# İstek, bilgisayarın yerel saatini UTC farkıyla birlikte taşır (ör. 2026-10-09T23:19:30+03:00); GitHub kararı bu saate göre verir.
# Asıl "günde bir kez" kuralı GitHub'daki iştedir; buradaki kontroller yalnızca boşuna istek atmamak için.
param([switch]$Test, [ValidateSet('watch', 'logoff', 'sleep', 'manual')][string]$Trigger = 'manual')

$ErrorActionPreference = 'Stop'
$dir = Join-Path $env:LOCALAPPDATA 'AksamNotu'
$configFile = Join-Path $dir 'ayarlar.json'
# Bu bilgisayarda Akşam Notu'nu kurmamış başka bir kullanıcı oturumu kapatıyorsa hiçbir şey yapma.
if (-not (Test-Path $configFile)) { exit 0 }

$log = Join-Path $dir 'gunluk.txt'
$lastFile = Join-Path $dir 'son-istek.txt'
Add-Type -AssemblyName System.Security

function Write-Log($text) {
  Add-Content -Path $log -Value ('{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss zzz'), $text) -Encoding UTF8
}

# Akşam 05:00'e kadar sürer: 00:30'daki kapanış bir önceki günün akşamı sayılır.
function Get-Evening([datetime]$at) { $at.AddHours(-5).ToString('yyyy-MM-dd') }

function Test-ShouldAsk([datetime]$at, $cfg) {
  if ($at.Hour -lt $cfg.startHour -and $at.Hour -ge 5) { return $false }
  -not ((Test-Path $lastFile) -and (Get-Content $lastFile -Raw).Trim() -eq (Get-Evening $at))
}

function Send-Reminder([string]$what, $cfg, [switch]$Test) {
  $now = Get-Date
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

  # Uykuya ve kapanışa saniyeler kaldığı için az ve hızlı dener.
  $tries = if ($what -eq 'Uyku (yedek)') { 4 } else { 2 }
  try {
    for ($try = 1; ; $try++) {
      try { Invoke-RestMethod @request | Out-Null; break }
      catch {
        $code = $_.Exception.Response.StatusCode.value__
        if ($code -in 401, 403, 404, 422 -or $try -ge $tries) { throw }
        Start-Sleep -Milliseconds (750 * $try)
      }
    }
    if (-not $Test) { Set-Content -Path $lastFile -Value (Get-Evening $now) }
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

$cfg = Get-Content $configFile -Raw | ConvertFrom-Json

if ($Trigger -ne 'watch') {
  $what = @{ logoff = 'Kapanış'; sleep = 'Uyku (yedek)'; manual = 'Elle' }[$Trigger]
  if (-not $Test -and -not (Test-ShouldAsk (Get-Date) $cfg)) { exit 0 }
  $ok = Send-Reminder $what $cfg -Test:$Test
  if ($Test -and -not $ok) { exit 1 }
  exit 0
}

# --- İzleyici ---
# Windows, ekran kapanırken ve kapak kapanırken çalışan programlara güç bildirimi gönderir (uyku başlamadan önce).
$source = @'
using System;
using System.Runtime.InteropServices;
using System.Threading;
using System.Windows.Forms;

public static class AksamWatcher {
  public static readonly AutoResetEvent Signal = new AutoResetEvent(false);
  public static volatile bool LidClosed;
  static readonly Guid DisplayState = new Guid("6FE69556-704A-47A0-8F24-C28D936FDA47"); // GUID_CONSOLE_DISPLAY_STATE
  static readonly Guid LidSwitch = new Guid("BA3E0F4D-B817-4094-A2D1-D56379E6A0F3");    // GUID_LIDSWITCH_STATE_CHANGE

  [DllImport("user32.dll")] static extern IntPtr RegisterPowerSettingNotification(IntPtr recipient, ref Guid setting, int flags);
  [StructLayout(LayoutKind.Sequential)] struct LASTINPUTINFO { public uint cbSize; public uint dwTime; }
  [DllImport("user32.dll")] static extern bool GetLastInputInfo(ref LASTINPUTINFO info);

  /// Milliseconds since the last keyboard or mouse input.
  public static uint IdleMs() {
    var info = new LASTINPUTINFO();
    info.cbSize = (uint)Marshal.SizeOf(info);
    GetLastInputInfo(ref info);
    return unchecked((uint)Environment.TickCount - info.dwTime);
  }

  class Receiver : NativeWindow {
    public Receiver() {
      CreateHandle(new CreateParams());
      var display = DisplayState; RegisterPowerSettingNotification(Handle, ref display, 0);
      var lid = LidSwitch; RegisterPowerSettingNotification(Handle, ref lid, 0);
    }
    protected override void WndProc(ref Message m) {
      // WM_POWERBROADCAST / PBT_POWERSETTINGCHANGE: POWERBROADCAST_SETTING { GUID; DWORD length; DWORD value }
      if (m.Msg == 0x218 && m.WParam.ToInt64() == 0x8013) {
        var setting = (Guid)Marshal.PtrToStructure(m.LParam, typeof(Guid));
        int value = Marshal.ReadInt32(m.LParam, 20);
        if (setting == LidSwitch) { LidClosed = value == 0; if (LidClosed) Signal.Set(); }
        else if (setting == DisplayState && value == 0) Signal.Set();
      }
      base.WndProc(ref m);
    }
  }

  public static void Start() {
    var thread = new Thread(() => { new Receiver(); Application.Run(); });
    thread.IsBackground = true;
    thread.SetApartmentState(ApartmentState.STA);
    thread.Start();
  }
}
'@
Add-Type -TypeDefinition $source -ReferencedAssemblies System.Windows.Forms
[AksamWatcher]::Start()
Write-Log 'İzleyici başladı.'

# Kullanıcının uyuttuğu durumlar (Kernel-Power 506 nedeni): 1 güç düğmesi, 11 ekranı kapatma isteği, 14 uyku düğmesi,
# 15 kapak, 20 Başlat > Uyku. Boşta kalınca ekranın kapanması (12) sayılmaz.
$userReasons = '1', '11', '14', '15', '20'

while ($true) {
  [void][AksamWatcher]::Signal.WaitOne()
  try {
    $signalAt = Get-Date
    if (-not (Test-ShouldAsk $signalAt $cfg)) { continue }

    # Kapak kapandıysa ya da az önce klavyeye/fareye dokunulduysa (Başlat > Uyku) bu kullanıcının isteğidir: hemen gönder.
    $why = $null
    if ([AksamWatcher]::LidClosed) { $why = 'Kapak' }
    elseif ([AksamWatcher]::IdleMs() -lt 30000) { $why = 'Uyku' }
    else {
      # Uzun süredir dokunulmamış: Windows'un uyku nedenine bak, boşta kalma (12) ise gönderme.
      $deadline = $signalAt.AddSeconds(3)
      while (-not $why -and (Get-Date) -lt $deadline) {
        $event = Get-WinEvent -FilterHashtable @{ LogName = 'System'; ProviderName = 'Microsoft-Windows-Kernel-Power'; Id = 506; StartTime = $signalAt.AddSeconds(-5) } -MaxEvents 1 -ErrorAction SilentlyContinue
        if ($event) {
          $reason = (([xml]$event.ToXml()).Event.EventData.Data | Where-Object Name -eq 'Reason').'#text'
          if ($reason -in $userReasons) { $why = 'Uyku' } else { break }
        } else { Start-Sleep -Milliseconds 250 }
      }
    }
    if ($why) { [void](Send-Reminder $why $cfg) }
  } catch {
    Write-Log "İzleyici: hata: $($_.Exception.Message)"
  }
}
