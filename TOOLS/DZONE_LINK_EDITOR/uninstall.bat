@echo off
setlocal
cd /d "%~dp0"

echo ============================================================
echo  DCORE Zone Link Editor - Uninstall
echo ============================================================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall.ps1" -Pause
set ERR=%ERRORLEVEL%

if not "%ERR%"=="0" (
  echo.
  echo UNINSTALL FAILED - error code %ERR%
  echo Check uninstall.log in this folder.
  echo.
)

pause
exit /b %ERR%
