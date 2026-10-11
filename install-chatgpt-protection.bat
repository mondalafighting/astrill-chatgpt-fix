@echo off
setlocal
echo.
echo ============================================================
echo   Install CodexLspExclusion
echo   Keeps Astrill's LSP out of ChatGPT (codex.exe) at the
echo   Windows level, and re-applies it after every ChatGPT update.
echo   Astrill and its LSP are not touched.
echo ============================================================
echo.
net session >nul 2>&1
if not %errorlevel%==0 (
  echo   [ERROR] Administrator rights required.
  echo           Right-click this file, then Run as administrator.
  echo.
  pause
  exit /b 1
)
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install-codex-lsp-exclusion.ps1"
echo.
echo   To remove it later: run uninstall-chatgpt-protection.bat as administrator.
echo.
pause
