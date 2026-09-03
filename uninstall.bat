@echo off
title KRUX Executor Uninstaller
color 0B
mode con: cols=70 lines=30

echo.
echo     ================================================================
echo                    KRUX Executor Uninstaller
echo     ================================================================
echo.

set "KRUX_DIR=%LOCALAPPDATA%\KRUX"

echo     [~] Removing KRUX from %KRUX_DIR%...
if exist "%KRUX_DIR%" (
    rd /s /q "%KRUX_DIR%" 2>nul
    echo     [+] KRUX removed!
) else (
    echo     [-] KRUX not found at %KRUX_DIR%
)
echo.

echo     [~] Removing desktop shortcut...
if exist "%USERPROFILE%\Desktop\KRUX Executor.lnk" (
    del /f /q "%USERPROFILE%\Desktop\KRUX Executor.lnk" 2>nul
    echo     [+] Desktop shortcut removed!
) else (
    echo     [-] Desktop shortcut not found
)
echo.

echo     [~] Removing Start Menu shortcut...
if exist "%APPDATA%\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk" (
    del /f /q "%APPDATA%\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk" 2>nul
    echo     [+] Start Menu shortcut removed!
) else (
    echo     [-] Start Menu shortcut not found
)
echo.

echo     ================================================================
echo                    KRUX Executor uninstalled successfully!
echo     ================================================================
echo.
echo     To reinstall: run install.bat
echo     Discord: https://discord.gg/krux
echo.

pause
