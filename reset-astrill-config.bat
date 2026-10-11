@echo off
setlocal
echo.
echo ============================================================
echo   Astrill login fix: reset its config (no reinstall)
echo   1. closes Astrill
echo   2. moves its config folder to Documents\astrill-config-backup\suspect-...
echo      (kept for analysis; Astrill will create a fresh one)
echo   3. starts Astrill - log in with your account and password
echo ============================================================
echo.
pause
taskkill /IM astrill.exe /F >nul 2>&1
timeout /t 3 /nobreak >nul
for /f %%i in ('powershell -NoProfile -Command "Get-Date -Format yyyyMMdd-HHmmss"') do set "STAMP=%%i"
set "SRC=%APPDATA%\Astrill"
set "DST=%USERPROFILE%\Documents\astrill-config-backup\suspect-%STAMP%"
if exist "%SRC%" (
  attrib -R "%SRC%\*" /S >nul 2>&1
  mkdir "%USERPROFILE%\Documents\astrill-config-backup" >nul 2>&1
  move "%SRC%" "%DST%" >nul
  echo   old config moved to: %DST%
) else (
  echo   no config folder found - nothing to move
)
rem launch through explorer so Astrill runs un-elevated even if this window was run as administrator
start "" explorer.exe "C:\Program Files (x86)\Astrill\astrill.exe"
echo.
echo   Astrill started with a fresh config. Log in now.
echo   Then tell Claude whether it worked and how long it took.
echo.
pause
