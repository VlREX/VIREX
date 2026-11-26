@echo off
setlocal
cd /d "%~dp0"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -STA -ExecutionPolicy RemoteSigned -File "%~dp0VIREX-Test-Studio.ps1"
if errorlevel 1 (
  echo.
  echo Studio failed to start. Read README.md for troubleshooting.
  pause
)
