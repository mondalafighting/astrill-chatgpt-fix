# Root cause and evidence

Investigated 2026-10-10/11 on Windows 11 (build 26200), ChatGPT desktop 26.1007.2314.0
(bundled codex-cli 0.162.0-alpha.17.2), Astrill 3.10.0.3073 (StealthVPN). Reproduced on a second PC.

## 1. The crash

`codex.exe app-server` (ChatGPT's backend, a 64-bit Rust binary) dies on its first network call:

```
Faulting application name: codex.exe
Faulting module name:      ASProxy64.dll, version 2.3.6.3   (C:\WINDOWS\system32\ASProxy64.dll)
Exception code:            0xc0000005 / 0xc000001d
Fault offset:              0x000000000000c27b
```

Facts that pin the cause on the LSP:

- `codex.exe --version` works; `codex.exe app-server` + one JSON-RPC `initialize` crashes every time
  while the LSP is registered, and never when it is not. Reproducible with a 15-line PowerShell probe.
- Enumerating the process modules shows `ASProxy64.dll` loaded into `codex.exe`.
- The Winsock catalog (`RegisterLSP64.exe -p -c 6`, shipped with Astrill) lists the five entries the
  installer adds (`ASProxy`, `ASProxy over [MSAFD Tcpip …]` ×4) in the 64-bit catalog, plus five in the
  32-bit catalog. `Microsoft-Windows-Winsock-WS2HELP/Operational` events 1/2 record every install/removal
  by `RegisterLSP(64).exe -b -w -d ASProxy(64).dll`.
- Other victims crash in the same code: JetBrains at `ASProxy64.dll+0xc274`, Windows MultiPoint
  (`WmsSvc.exe`) and GitHub Desktop at `+0xc277`/`+0xc27b` on this machine, i.e. the same function.
- The ChatGPT desktop app **does not run the Store copy** of `codex.exe`. It copies the runtime to
  `%LOCALAPPDATA%\OpenAI\Codex\bin\<16-hex>\codex.exe` on the first launch after each update
  (`copiedRuntimeLocation=true` in its logs) and runs that. The folder name is not a hash of the binary
  we could derive. Crashes of that copy are not written to the Application event log (WER throttling);
  the ChatGPT log shows them as `app-server websocket closed (code=3221225477|3221225501)`.

## 2. Why not just remove the LSP

Astrill's hidden *Help → LSP Uninstall* runs `sc stop ASProxy; ASProxy.exe /Unregserver;
registerlsp -f; registerlsp64 -f`. It fixes ChatGPT immediately. But:

- On this setup Astrill login failed after removing the LSP (twice) — with hindsight that was most
  likely the config-corruption bug in section 4, which the removal step happened to trigger. Either way
  the user ends up reinstalling Astrill, which reinstalls the LSP, which breaks ChatGPT again.
- Astrill's current Windows build (3.10.0.3073, 2025-02) still ships the 2016 LSP, so no upstream fix.

## 3. The fix: per-application LSP category

Windows Vista+ decides per process which LSPs to load
([docs](https://learn.microsoft.com/en-us/windows/win32/winsock/categorizing-layered-service-providers-and-applications)):

- an application with **no** category loads every LSP;
- an application **with** a category loads only LSPs whose categories are a subset of it;
- an LSP with no category has category 0 — Astrill's has none (`WSCGetProviderInfo` → `0x00000000`).

So `WSCSetApplicationCategory(path, LSP_SYSTEM)` on `codex.exe` makes Windows skip the Astrill LSP for
that executable, with the LSP still installed for everything else. Verified: after categorization
`codex.exe` no longer has `ASProxy64.dll` in its module list and the probe no longer crashes.

Categories are keyed by **full path** (`HKLM\SYSTEM\CurrentControlSet\Services\WinSock2\Parameters\AppId_Catalog`),
hence the scheduled task:

- trigger: `Microsoft-Windows-AppModel-Runtime/Admin` event 201 with
  `ApplicationName='OPENAI.CODEX_2P2NQSD0C76G0!APP'` (every ChatGPT launch), delay 30 s, then re-check
  every 30 s for 3 minutes (the copied runtime appears seconds after launch);
- targets: the Store package, `%LOCALAPPDATA%\OpenAI\Codex\bin\*\codex.exe`, the standalone Codex CLI
  (`%LOCALAPPDATA%\Programs\OpenAI\Codex\bin`), the npm-installed CLI;
- the categories survive Astrill reinstalls (verified) and reboots; ChatGPT updates create a new folder,
  which the next launch trigger covers (the very first launch after an update may show the sign-in error
  for ~30 s, then recovers or needs one *Retry*).

Alternatives considered: Astrill *Settings → Application Filter* (only routes traffic; the LSP still
loads — verified no effect); Astrill's hidden *Help → Hard excluded apps* with `codex.exe` (works, but
the list is wiped by every Astrill reinstall); removing only the 64-bit LSP (ChatGPT fixed, Astrill
login then failed on this setup); IFEO/AppLocker DLL blocking (too blunt).

## 4. The second bug: Astrill's own login failures

Symptom: after a reboot or after *Exit*, Astrill either shows a login failure or simply dies
11–66 s after starting. Event log data (`Application Error` 1000, `Data[9]` = process start time)
shows the failing instances living seconds, while healthy ones live hours and crash only on exit —
always in `ntdll.dll` at offset `0x6f7aa` (heap corruption on shutdown).

Evidence that the carrier is the config file:

- every recovery coincided with a freshly **created** `%APPDATA%\Astrill\Astrill.ini` (reinstall after
  an uninstall that removed the folder, or our config-reset tool); reinstalls that kept the file did not help;
- the file taken from a failing state had `LastWriteTime` equal to the shutdown time — Astrill rewrote
  it while being killed; it was ~700 bytes larger than good samples, not truncated (encrypted per file,
  magic `ASTR`, so contents cannot be compared);
- a clean in-app *Logout → Login* never failed; *Logout* before reboot did not prevent the failure;
- with `Astrill.ini` read-only, both *Exit → reopen* and a reboot started Astrill logged in, with the
  chosen protocol, no crash on start.

Astrill writes `Astrill.ini` on login and on a protocol change only (not on disconnect/reconnect), which
is why the lock step says to switch the protocol away and back before locking.

## 5. The third nuisance: ChatGPT starting before the VPN

ChatGPT's Store start-at-login task (re-enabled by its reinstall) launched the app ~16 s after boot,
minutes before the VPN was connected; `getAuthStatus` timed out and the app showed the sign-in page.
`disable-chatgpt-autostart` sets the task's `State` to 0 (the same thing *Task Manager → Startup apps →
Disable* does). Re-check after ChatGPT updates.

## 6. Timeline of the two-day investigation (abridged)

| Step | Result |
|---|---|
| Network/Cloudflare theories, cookie cleaning, node changes | no effect — the crash is local |
| Remove LSP (script, then Astrill's own menu) | ChatGPT fixed; Astrill login failures followed → reinstall loop |
| Astrill Application Filter exclusion | no effect |
| Astrill Hard excluded apps = `codex.exe` | works, wiped on reinstall |
| `WSCSetApplicationCategory` on the Store `codex.exe` only | missed the copied runtime → still crashed |
| Category on all copies + launch trigger | **works**, survives reinstalls and reboots |
| Astrill: wait 30 min / logout before reboot | no effect |
| Astrill: fresh config | works; read-only lock makes it permanent |
