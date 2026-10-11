# Astrill VPN × ChatGPT desktop crash fix (Windows)

**Symptom:** the ChatGPT desktop app (Microsoft Store, package `OpenAI.Codex`) shows
*"Unable to load sign-in requirements"* and never signs in. Event Viewer → Windows Logs →
Application shows the backend crashing inside Astrill's network component:

```
Faulting application name: codex.exe
Faulting module name:      ASProxy64.dll, version: 2.3.6.3
Exception code:            0xc0000005 (or 0xc000001d)
Fault offset:              0x000000000000c27b
```

`ASProxy64.dll` is Astrill's Winsock **LSP** (Layered Service Provider, a 2016 Komodia redirector).
The Astrill installer registers it on every install, Windows loads it into every program that opens a
socket, and in ChatGPT's backend (`codex.exe`, 64-bit) it crashes on the first network call. The same DLL
also crashes the standalone Codex CLI, JetBrains IDEs ([JBR-8076](https://youtrack.jetbrains.com/issue/JBR-8076)),
Cursor, Lightroom, Steam and others.

**The usual advice — Astrill's hidden "LSP Uninstall" or `netsh winsock reset` — fixes ChatGPT but on
some setups breaks Astrill's own login, and every Astrill reinstall brings the LSP back anyway.**

This repository keeps the LSP installed and instead tells Windows to never load it into `codex.exe`.
Astrill is untouched. 中文说明见 [README.zh-CN.md](README.zh-CN.md)。

## How it works

| Piece | What it does |
|---|---|
| `codex-lsp-exclusion.ps1` | Gives every `codex.exe` on the machine a Winsock *application category* (`WSCSetApplicationCategory`, `LSP_SYSTEM`). Windows then only loads LSPs whose categories match; Astrill's LSP is uncategorized, so it is never loaded into `codex.exe`. Nothing is removed. |
| Scheduled task `CodexLspExclusion` | Categories are stored **per path**, and the ChatGPT desktop app copies its backend to `%LOCALAPPDATA%\OpenAI\Codex\bin\<random>\codex.exe` on the first launch after every update. The task therefore runs the script as SYSTEM **30 s after every ChatGPT launch** (event `Microsoft-Windows-AppModel-Runtime/Admin` 201) and re-checks for 3 minutes. Survives ChatGPT updates and Astrill reinstalls. |
| `disable-chatgpt-autostart` | Turns off ChatGPT's start-at-login task. When ChatGPT starts before the VPN is up it cannot verify the account and shows a sign-in page. |
| `lock-astrill-config` / `unlock-astrill-config` | **Separate Astrill bug:** `astrill.exe` crashes on exit (`ntdll`, offset `0x6f7aa`) and the config it writes while dying (`%APPDATA%\Astrill\Astrill.ini`) is sometimes corrupt, so the next start fails to log in. Locking a known-good `Astrill.ini` read-only stops the exit-time write; Astrill then starts logged in with your protocol every time. |
| `reset-astrill-config` | If Astrill will not log in: moves the config folder aside (kept for analysis) and restarts Astrill with a fresh config — 1 minute instead of a reinstall. |
| `check-status` | Read-only diagnosis: confirms the symptom and shows the state of every piece above. |

## Quick start

Requirements: Windows 10/11, Windows PowerShell 5.1 (built in). Only step 2 needs administrator rights.
If SmartScreen says "Windows protected your PC", click *More info → Run anyway*.

1. **`check-status.bat`** — confirm it is this problem (`codex.exe crashes in ASProxy64.dll` > 0).
2. **`install-chatgpt-protection.bat`** — right-click → *Run as administrator* → wait for `[OK]`.
   Then quit ChatGPT completely (tray icon too) and start it again.
3. **`disable-chatgpt-autostart.bat`** — so ChatGPT no longer starts before your VPN.
   (Also consider turning off Windows *Settings → Accounts → Sign-in options → Automatically save my
   restartable apps and restart them when I sign back in*.)
4. **Astrill config lock** — get Astrill into the state you want: logged in, VPN **OFF**, switch the
   protocol *away and back* (e.g. OpenWeb → StealthVPN — Astrill only saves settings on login and on a
   protocol change), then connect. Now run **`lock-astrill-config.bat`**.
5. Reboot once to verify: open Astrill (already logged in, your protocol), connect, open ChatGPT.

Logs: `C:\ProgramData\CodexLspExclusion\exclusion.log`. Uninstall: `uninstall-chatgpt-protection.bat`
(administrator) and `unlock-astrill-config.bat`.

## If something goes wrong

| Situation | Do this |
|---|---|
| ChatGPT shows the sign-in error right after a ChatGPT update | Wait 30 s and click *Retry*, or quit and reopen ChatGPT. The first launch after an update can race the task once. |
| ChatGPT shows the sign-in error at any other time | Run `check-status.bat`; re-run step 2. |
| Astrill crashes within a minute of starting / will not log in | `reset-astrill-config.bat` (normal double-click, **not** as administrator), log in, redo step 4. |
| You changed an Astrill setting and it reverts after reboot | `unlock-astrill-config.bat` → change it in Astrill (switch the protocol away and back) → `lock-astrill-config.bat`. |

Do **not** use Astrill's *LSP Uninstall*, `netsh winsock reset`, or delete `ASProxy*.dll`.

## Tested on

Windows 11 (build 26200) · ChatGPT desktop 26.1007.2314.0 (codex-cli 0.162.0-alpha.17.2) ·
Astrill 3.10.0.3073, StealthVPN. Two machines. Details and evidence: [docs/ROOT-CAUSE.md](docs/ROOT-CAUSE.md).

## References

- [openai/codex#30884](https://github.com/openai/codex/issues/30884) — the open upstream issue
- [JetBrains JBR-8076](https://youtrack.jetbrains.com/issue/JBR-8076) — same DLL, same crash
- [Microsoft: Categorizing layered service providers and applications](https://learn.microsoft.com/en-us/windows/win32/winsock/categorizing-layered-service-providers-and-applications)
- [Astrill wiki: LSP Install / Uninstall menu](https://www.astrill.com/wiki/Astrill_Application:Other_menus_and_options)

## License

MIT. The investigation and scripts were produced together with Claude (Anthropic).
