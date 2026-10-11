@echo off
setlocal
net session >nul 2>&1
if not %errorlevel%==0 (
  echo   [ERROR] Administrator rights required.
  echo           Right-click this file, then Run as administrator.
  echo.
  pause
  exit /b 1
)
schtasks /Delete /TN CodexLspExclusion /F
if exist "C:\Program Files\CodexLspExclusion" rmdir /S /Q "C:\Program Files\CodexLspExclusion"
echo.
echo   Task removed. Log kept in C:\ProgramData\CodexLspExclusion\
echo   Categories already set stay until ChatGPT updates to a new version folder.
echo.
pause
