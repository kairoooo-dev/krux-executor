@echo off
title KRUX Executor Installer
color 0B
cls
echo.
echo    ================================================================
echo.
echo      KKKKKKKKKKKKKKK   RRRRRRRRRRRRRRRRR   UUUUUUUUUUU   XXXXXXXXX
echo      KKKKKKKKKKKKKKK   RRRRRRRRRRRRRRRRR   UUUUUUUUUUU   XXXXXXXXX
echo      KKKKKK            RRRRRR    RRRRRR    UUUUUUUUUUU   XXXXXXXXX
echo      KKKKKK            RRRRRR    RRRRRR    UUUU   UUUU   XXXXXXXXX
echo      KKKKKK            RRRRRRRRRRRRRRR     UUU    UUUU   XXXXXXXXX
echo      KKKKKK            RRRRRR    RRRRR      UUUUUUUUUU   XXXXXXXXX
echo      KKKKKKKKKKKKKKK   RRRRRR    RRRRR       UUUUUUUUU   XXXXXXXXX
echo      KKKKKKKKKKKKKKK   RRRRRR    RRRRR        UUUUUUUU   XXXXXXXXX
echo.
echo    ================================================================
echo                     KRUX Executor Installer v2.0
echo    ================================================================
echo.
echo    This will install KRUX Executor to your system.
echo    Requires Windows 10/11 and PowerShell.
echo.
echo    [1] Install KRUX Executor
echo    [2] Exit
echo.
set /p choice="    Select option: "
if "%choice%"=="2" exit /b
echo.
echo    Starting installer...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "iex (irm 'https://raw.githubusercontent.com/kairoooo-dev/krux-executor/master/install.ps1')"

echo.
echo    Press any key to exit...
pause >nul
