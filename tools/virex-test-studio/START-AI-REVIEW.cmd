@echo off
setlocal
cd /d "%~dp0"
where py.exe >nul 2>nul
if not errorlevel 1 (
  py -3 "%~dp0ai_review.py"
) else (
  python "%~dp0ai_review.py"
)
pause
