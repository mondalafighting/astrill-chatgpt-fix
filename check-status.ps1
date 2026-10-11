# Read-only status check for the Astrill + ChatGPT desktop problem. No admin needed. Changes nothing.
$ErrorActionPreference = 'SilentlyContinue'
$sep = '------------------------------------------------------------'
"Windows: " + (Get-CimInstance Win32_OperatingSystem).Caption + " build " + (Get-CimInstance Win32_OperatingSystem).BuildNumber + "   user: $env:USERNAME"
$sep
"[Astrill]"
$ast = 'C:\Program Files (x86)\Astrill'
if (Test-Path "$ast\astrill.exe") {
    "  installed: version " + (Get-Item "$ast\astrill.exe").VersionInfo.FileVersion
    $l64 = (& "$ast\RegisterLSP64.exe" -p -c 6 2>&1 | Select-String 'ASProxy' | Measure-Object).Count
    $l32 = (& "$ast\RegisterLSP.exe" -p -c 3 2>&1 | Select-String 'ASProxy' | Measure-Object).Count
    "  LSP entries: 64-bit=$l64  32-bit=$l32   (5/5 = normal Astrill install; do NOT remove them)"
    $svc = Get-Service ASProxy; "  ASProxy service: " + $(if ($svc) { $svc.Status } else { 'not installed' })
} else { "  not installed" }
$p = Get-Process astrill
"  astrill.exe running: " + $(if ($p) { "yes (since $($p.StartTime.ToString('HH:mm:ss')), elevated=$([string]::IsNullOrEmpty($p.Path)))" } else { 'no' })
$ini = "$env:APPDATA\Astrill\Astrill.ini"
if (Test-Path $ini) { $f = Get-Item $ini; "  Astrill.ini: {0} bytes, last written {1}, read-only={2}" -f $f.Length, $f.LastWriteTime.ToString('MM-dd HH:mm:ss'), $f.IsReadOnly } else { "  Astrill.ini: not found" }
"  astrill.exe crashes (last 7 days): " + (Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Application Error'; StartTime=(Get-Date).AddDays(-7)} | Where-Object { $_.Message -match 'Faulting application name: astrill.exe' } | Measure-Object).Count
$sep
"[ChatGPT desktop]"
$pk = Get-AppxPackage -Name OpenAI.Codex
"  package: " + $(if ($pk) { ($pk | ForEach-Object Version) -join ', ' } else { 'not installed' })
$cr = Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='Application Error'; StartTime=(Get-Date).AddDays(-7)} | Where-Object { $_.Message -match 'codex.exe' -and $_.Message -match 'ASProxy' }
"  codex.exe crashes in ASProxy64.dll (last 7 days): " + ($cr | Measure-Object).Count + $(if ($cr) { "  (last: " + ($cr | Select-Object -First 1).TimeCreated.ToString('MM-dd HH:mm') + ")  <- the symptom" } else { '' })
"  protection task installed: " + (Test-Path 'C:\Program Files\CodexLspExclusion\codex-lsp-exclusion.ps1')
$log = 'C:\ProgramData\CodexLspExclusion\exclusion.log'
if (Test-Path $log) { "  last task run: " + (Get-Content $log -Tail 1) }
$chk = Join-Path $PSScriptRoot 'codex-lsp-exclusion.ps1'
if (Test-Path $chk) { "  codex.exe copies and their protection:"; & powershell.exe -NoProfile -ExecutionPolicy Bypass -File $chk -Check | ForEach-Object { "    " + ($_ -replace '^\S+ \S+  ', '') } }
$task = Get-ChildItem 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\CurrentVersion\AppModel\SystemAppData' | Where-Object { $_.PSChildName -like 'OpenAI.Codex_*' } | ForEach-Object { Get-ItemProperty "$($_.PSPath)\App" } | Select-Object -First 1
"  ChatGPT start-at-login: " + $(if ($null -eq $task.State) { 'unknown' } elseif ($task.State -eq 0) { 'disabled' } else { "ENABLED (State=$($task.State))" })
"  Windows 'restart apps after sign-in': " + $(if ((Get-ItemProperty 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon').RestartApps -eq 1) { 'on' } else { 'off' })
$sep
"VPN exit (chatgpt.com): " + ((curl.exe -s -m 10 https://chatgpt.com/cdn-cgi/trace | Select-String '^(ip|loc)=' | ForEach-Object { $_.Line }) -join ' ')
