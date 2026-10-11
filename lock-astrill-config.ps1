# Locks (or unlocks with -Unlock) Astrill's config file so a crashing exit cannot overwrite it. No admin needed.
param([switch]$Unlock)
$ini = "$env:APPDATA\Astrill\Astrill.ini"
if (-not (Test-Path $ini)) { "  [ERROR] $ini not found. Open Astrill and log in first."; exit 1 }
$f = Get-Item $ini
if ($Unlock) {
    Set-ItemProperty $ini -Name IsReadOnly -Value $false
    "  [OK] Astrill.ini is writable again. Make your change in Astrill (e.g. switch protocol OFF -> OpenWeb -> StealthVPN), then run lock again."
    exit 0
}
"  Astrill.ini: {0} bytes, last written {1}" -f $f.Length, $f.LastWriteTime.ToString('MM-dd HH:mm:ss')
if (-not (Get-Process astrill -ErrorAction SilentlyContinue)) { "  [!] Astrill is not running. Lock only while Astrill is logged in and working." }
"  [i] Make sure you switched the protocol away and back (OFF -> other protocol -> your protocol -> ON) BEFORE locking:"
"      Astrill writes its settings only on login and on protocol change, so an unswitched file may still hold the default protocol."
$bk = Join-Path $env:USERPROFILE ('Documents\astrill-config-backup\working-' + (Get-Date -Format 'yyyyMMdd-HHmm'))
New-Item -ItemType Directory -Force -Path $bk | Out-Null
Copy-Item "$env:APPDATA\Astrill\*" $bk -Force
Set-ItemProperty $ini -Name IsReadOnly -Value $true
"  [OK] Astrill.ini is now read-only. Snapshot saved to $bk"
"       Astrill keeps working; settings changed later will NOT persist across restarts (unlock -> change -> lock to make them permanent)."
