# CodexLspExclusion - keeps Astrill's Winsock LSP (ASProxy64.dll) out of ChatGPT's backend codex.exe.
#
# Astrill's LSP is uncategorized (category 0). Once an application is given any LSP category
# (WSCSetApplicationCategory), Windows loads only LSPs whose categories match it, so the Astrill LSP is
# never loaded into that application. The LSP itself stays installed and Astrill is not touched.
# Categories are stored per executable path, and the ChatGPT desktop app copies its backend to a new
# random folder on the first launch after every update - so the scheduled task "CodexLspExclusion"
# runs this 30 s after every ChatGPT launch (with -Watch: re-checks every 30 s for a few minutes).
#
# -Check: report only, change nothing (works without admin rights).
param([switch]$Check, [switch]$Watch)

$ErrorActionPreference = 'Continue'
$Log = 'C:\ProgramData\CodexLspExclusion\exclusion.log'
$LSP_SYSTEM = [uint32]2147483648   # 0x80000000 (PowerShell 5.1 reads the hex literal as a negative Int32)

Add-Type -TypeDefinition @'
using System; using System.Runtime.InteropServices;
public static class WscCat {
  [DllImport("ws2_32.dll", CharSet = CharSet.Unicode)]
  public static extern int WSCSetApplicationCategory(string path, uint pathLen, string extra, uint extraLen, uint permitted, out uint prev, out int err);
  [DllImport("ws2_32.dll", CharSet = CharSet.Unicode)]
  public static extern int WSCGetApplicationCategory(string path, uint pathLen, string extra, uint extraLen, out uint cat, out int err);
}
'@

function Write-Log([string]$msg) {
    $line = '{0}  {1}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'), $msg
    if ($Check) { Write-Host $line; return }
    $dir = Split-Path $Log
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if ((Test-Path $Log) -and (Get-Item $Log).Length -gt 1MB) { Move-Item $Log "$Log.old" -Force }
    Add-Content -Path $Log -Value $line
}

# Every codex.exe that ChatGPT or Codex runs on this machine.
function Get-CodexTargets {
    try { $pkgs = @(Get-AppxPackage -AllUsers -Name OpenAI.Codex -ErrorAction Stop) }   # -AllUsers needs admin
    catch { $pkgs = @(Get-AppxPackage -Name OpenAI.Codex -ErrorAction SilentlyContinue) }
    $t = @($pkgs | ForEach-Object { Join-Path $_.InstallLocation 'app\resources\codex.exe' })
    $t += @(Resolve-Path -ErrorAction SilentlyContinue -Path @(
        'C:\Users\*\AppData\Local\OpenAI\Codex\bin\*\codex.exe',          # the copy the desktop app actually runs
        'C:\Users\*\AppData\Local\Programs\OpenAI\Codex\bin\codex.exe',   # standalone Codex CLI
        'C:\Users\*\AppData\Roaming\npm\node_modules\@openai\codex\node_modules\@openai\codex-win32-x64\vendor\*\bin\codex.exe'
    ) | ForEach-Object ProviderPath)
    @($t | Where-Object { $_ -and (Test-Path $_) } | Sort-Object -Unique)
}

# One pass. $quiet: log changes only (used by the -Watch re-checks). Returns the number of failures.
function Invoke-Pass([bool]$quiet) {
    $failed = 0
    foreach ($exe in Get-CodexTargets) {
        $cat = [uint32]0; $err = 0
        $rc = [WscCat]::WSCGetApplicationCategory($exe, [uint32]$exe.Length, $null, 0, [ref]$cat, [ref]$err)
        if ($rc -eq 0 -and $cat -ne 0) { if (-not $quiet) { Write-Log ("ok: {0}" -f $exe) }; continue }
        if ($Check) { Write-Log "NOT protected (would set now): $exe"; continue }
        $prev = [uint32]0
        $rc = [WscCat]::WSCSetApplicationCategory($exe, [uint32]$exe.Length, $null, 0, $LSP_SYSTEM, [ref]$prev, [ref]$err)
        if ($rc -eq 0) { Write-Log "SET: $exe" } else { Write-Log "FAILED (err $err): $exe"; $failed++ }
    }
    return $failed
}

$failed = Invoke-Pass $false
if ($Watch -and -not $Check) {
    foreach ($i in 1..5) { Start-Sleep -Seconds 30; $failed = Invoke-Pass $true }
}
exit $failed
