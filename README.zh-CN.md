# Astrill VPN × ChatGPT 桌面版 崩溃修复（Windows）

**症状**：ChatGPT 桌面版（微软商店版，包名 `OpenAI.Codex`）一直显示「无法加载登录要求 / 重试」。
事件查看器 → Windows 日志 → 应用程序里能看到后台进程崩在 Astrill 的网络组件里：

```
Faulting application name: codex.exe
Faulting module name:      ASProxy64.dll, version: 2.3.6.3
Exception code:            0xc0000005（或 0xc000001d）
```

`ASProxy64.dll` 是 Astrill 的 Winsock **LSP**（分层服务提供程序，2016 年的 Komodia 组件）。
Astrill 每次安装都会把它注册进系统，Windows 会把它装进每一个联网程序；在 ChatGPT 的 64 位后台
`codex.exe` 里，它一处理网络请求就崩溃。同一个 DLL 也会搞崩独立版 Codex CLI、JetBrains IDE
（[JBR-8076](https://youtrack.jetbrains.com/issue/JBR-8076)）、Cursor、Lightroom、Steam 等。

**网上常见的办法——Astrill 隐藏菜单的「LSP Uninstall」或 `netsh winsock reset`——能修好 ChatGPT，
但在部分环境下 Astrill 自己会登录不上，而且重装 Astrill 又会把 LSP 装回来。**

本仓库**保留 LSP**，改为让 Windows 永远不把它装进 `codex.exe`。Astrill 一点不动。

## 原理

| 部件 | 作用 |
|---|---|
| `codex-lsp-exclusion.ps1` | 给机器上每一份 `codex.exe` 设置 Winsock「应用程序类别」（`WSCSetApplicationCategory`，`LSP_SYSTEM`）。设置后 Windows 只加载类别匹配的 LSP；Astrill 的 LSP 没有类别，于是不会进入 `codex.exe`。什么都不删。 |
| 计划任务 `CodexLspExclusion` | 类别是**按路径**存的，而 ChatGPT 桌面版每次更新后第一次启动，会把后台复制到 `%LOCALAPPDATA%\OpenAI\Codex\bin\<随机名>\codex.exe` 再运行。所以任务以 SYSTEM 身份在**每次 ChatGPT 启动后 30 秒**运行脚本（事件 `Microsoft-Windows-AppModel-Runtime/Admin` 201），并复查 3 分钟。ChatGPT 更新、Astrill 重装都不影响。 |
| `disable-chatgpt-autostart` | 关闭 ChatGPT 的开机自启。它若抢在 VPN 之前启动，验证不了账号，就会要求重新登录。 |
| `lock-astrill-config` / `unlock-astrill-config` | **Astrill 自己的另一个 bug**：`astrill.exe` 退出时崩溃（`ntdll`，偏移 `0x6f7aa`），崩溃过程中写出的配置文件（`%APPDATA%\Astrill\Astrill.ini`）有时是坏的，下次启动就登录不上。把一份健康的 `Astrill.ini` 设为只读，退出时就写不坏，每次启动都直接是登录状态和你选的协议。 |
| `reset-astrill-config` | Astrill 登录不上时：把配置文件夹挪走留样，用全新配置重开 Astrill——1 分钟，不用重装。 |
| `check-status` | 只读诊断：确认症状，显示上述每一项的状态。 |

## 快速开始

要求：Windows 10/11，自带的 Windows PowerShell 5.1。只有第 2 步需要管理员权限。
若提示「Windows 已保护你的电脑」：点「更多信息」→「仍要运行」。

1. **`check-status.bat`** —— 确认是这个问题（`codex.exe crashes in ASProxy64.dll` 大于 0）。
2. **`install-chatgpt-protection.bat`** —— 右键 → 以管理员身份运行 → 看到 `[OK]`。
   然后完全退出 ChatGPT（托盘图标也退出）再重新打开。
3. **`disable-chatgpt-autostart.bat`** —— 让 ChatGPT 不再抢在 VPN 之前启动。
   （也建议关闭 Windows「设置 → 账户 → 登录选项 → 登录后自动重启应用」。）
4. **锁定 Astrill 配置** —— 先把 Astrill 调到你要的状态：已登录、开关 **OFF**、把协议*切走再切回*
   （例如 OpenWeb → StealthVPN。Astrill 只在登录和切换协议时才保存设置，哪怕显示的已经是你要的协议也要切一次），
   再连接。然后运行 **`lock-astrill-config.bat`**。
5. 重启一次验证：打开 Astrill（直接是登录状态和你的协议）→ 连接 → 打开 ChatGPT。

日志：`C:\ProgramData\CodexLspExclusion\exclusion.log`。卸载：`uninstall-chatgpt-protection.bat`（管理员）
和 `unlock-astrill-config.bat`。

## 出问题时

| 情况 | 做法 |
|---|---|
| ChatGPT 刚更新完第一次打开就报登录错误 | 等 30 秒点「重试」，或退出重开。更新后的第一次启动可能比任务早一步，只会发生一次。 |
| 其他时候 ChatGPT 报登录错误 | 运行 `check-status.bat`，重做第 2 步。 |
| Astrill 启动后几十秒就没了 / 登录不上 | `reset-astrill-config.bat`（普通双击，**不要**用管理员），登录，重做第 4 步。 |
| 改了 Astrill 设置，重启后又变回去 | `unlock-astrill-config.bat` → 在 Astrill 里改（协议切走再切回）→ `lock-astrill-config.bat`。 |

**不要**用 Astrill 的「LSP Uninstall」、不要 `netsh winsock reset`、不要删 `ASProxy*.dll`。

## 测试环境

Windows 11（26200）· ChatGPT 桌面版 26.1007.2314.0（codex-cli 0.162.0-alpha.17.2）·
Astrill 3.10.0.3073，StealthVPN。两台电脑验证。证据与分析见 [docs/ROOT-CAUSE.md](docs/ROOT-CAUSE.md)（英文）。

## 许可

MIT。排查与脚本由作者与 Claude（Anthropic）共同完成。
