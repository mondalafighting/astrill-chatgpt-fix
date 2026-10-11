# Installs the CodexLspExclusion scheduled task. Run via install-codex-lsp-exclusion.bat (as administrator).
$ErrorActionPreference = 'Stop'

$me = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $me.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host '  [ERROR] Administrator rights required.'
    exit 1
}

$TaskName = 'CodexLspExclusion'
$DstDir   = 'C:\Program Files\CodexLspExclusion'
$DstPs1   = Join-Path $DstDir 'codex-lsp-exclusion.ps1'
$Log      = 'C:\ProgramData\CodexLspExclusion\exclusion.log'

Write-Host '  [1/3] Copy script to' $DstDir
New-Item -ItemType Directory -Force -Path $DstDir | Out-Null
Copy-Item (Join-Path $PSScriptRoot 'codex-lsp-exclusion.ps1') $DstPs1 -Force

# The trigger reads ChatGPT launch events from this log; make sure it is enabled.
$ch = 'Microsoft-Windows-AppModel-Runtime/Admin'
if (-not (Get-WinEvent -ListLog $ch).IsEnabled) { wevtutil sl $ch /e:true; Write-Host "  enabled event log: $ch" }

Write-Host '  [2/3] Register scheduled task' $TaskName '(runs as SYSTEM 30 s after every ChatGPT launch)'
Stop-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue
$xml = @"
<?xml version="1.0" encoding="UTF-16"?>
<Task version="1.2" xmlns="http://schemas.microsoft.com/windows/2004/02/mit/task">
  <RegistrationInfo>
    <Description>Keeps Astrill's LSP (ASProxy64.dll) out of ChatGPT's backend codex.exe by giving codex.exe a Winsock LSP category. Runs 30 s after every ChatGPT launch and re-checks for 3 minutes, because ChatGPT copies its backend to a new random folder on the first launch after an update. Log: $Log</Description>
  </RegistrationInfo>
  <Triggers>
    <EventTrigger>
      <Enabled>true</Enabled>
      <Delay>PT30S</Delay>
      <Subscription>&lt;QueryList&gt;&lt;Query Id="0" Path="Microsoft-Windows-AppModel-Runtime/Admin"&gt;&lt;Select Path="Microsoft-Windows-AppModel-Runtime/Admin"&gt;*[System[(EventID=201)]] and *[EventData[Data[@Name='ApplicationName']='OPENAI.CODEX_2P2NQSD0C76G0!APP']]&lt;/Select&gt;&lt;/Query&gt;&lt;/QueryList&gt;</Subscription>
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
    <StartWhenAvailable>true</StartWhenAvailable>
    <ExecutionTimeLimit>PT5M</ExecutionTimeLimit>
    <Enabled>true</Enabled>
  </Settings>
  <Actions Context="Author">
    <Exec>
      <Command>powershell.exe</Command>
      <Arguments>-NoProfile -NonInteractive -ExecutionPolicy Bypass -File "$DstPs1" -Watch</Arguments>
    </Exec>
  </Actions>
</Task>
"@
Register-ScheduledTask -TaskName $TaskName -Xml $xml -Force | Out-Null

Write-Host '  [3/3] Protect every codex.exe now'
& powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $DstPs1

Write-Host ''
Write-Host '  --- log (last lines) ---'
Get-Content $Log -Tail 6 | ForEach-Object { Write-Host "  $_" }
Write-Host ''
$last = Get-Content $Log -Tail 6 | Out-String
if ($last -match 'FAILED') { Write-Host '  [!] Some codex.exe could not be protected - please report the log above.' }
elseif ($last -match 'SET:|ok:') { Write-Host '  [OK] Every codex.exe is protected. Restart ChatGPT once. From now on this is re-applied automatically 30 s after every ChatGPT launch.' }
else { Write-Host '  [!] Unexpected result - please report the log above.' }
