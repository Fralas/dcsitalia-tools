@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo  DCORE Zone Link Editor - Install
echo ============================================================
echo.

REM Prefer Windows PowerShell 5.1 (ships with Windows)
where powershell >nul 2>&1
if errorlevel 1 (
  echo ERROR: powershell.exe not found.
  goto :fail
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" -Pause
set ERR=%ERRORLEVEL%

if not "%ERR%"=="0" goto :fail

echo.
echo Install log: %~dp0install.log
echo.
pause
exit /b 0

:fail
echo.
echo INSTALL FAILED - error code %ERR%
echo Check install.log in this folder for details.
echo.
echo Common fixes:
echo   1. Edit dcs-path.txt with the full DCS folder path
echo   2. Run this .bat as Administrator if DCS is under Program Files
echo   3. Fully restart DCS after a successful install
echo.
pause
exit /b %ERR%
