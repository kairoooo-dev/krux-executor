@echo off
title KRUX Executor Installer
color 0B
mode con: cols=70 lines=35

echo.
echo     KKKKKKKKKKKKKKK   RRRRRRRRRRRRRRRRR   UUUUUUUUUUU   XXXXXXXXX
echo     KKKKKKKKKKKKKKK   RRRRRRRRRRRRRRRRR   UUUUUUUUUUU   XXXXXXXXX
echo     KKKKKK            RRRRRR    RRRRRR    UUUUUUUUUUU   XXXXXXXXX
echo     KKKKKK            RRRRRR    RRRRRR    UUUU   UUUU   XXXXXXXXX
echo     KKKKKK            RRRRRRRRRRRRRRR     UUU    UUUU   XXXXXXXXX
echo     KKKKKK            RRRRRR    RRRRR      UUUUUUUUUU   XXXXXXXXX
echo     KKKKKKKKKKKKKKK   RRRRRR    RRRRR       UUUUUUUUU   XXXXXXXXX
echo     KKKKKKKKKKKKKKK   RRRRRR    RRRRR        UUUUUUUU   XXXXXXXXX
echo.
echo     ================================================================
echo                    KRUX Executor Installer v3.0
echo     ================================================================
echo.

:: Set install directory
set "KRUX_DIR=%LOCALAPPDATA%\KRUX"
set "TEMP_DIR=%TEMP%\KRUX_Install"
set "REPO=kairoooo-dev/krux-executor"
set "API_URL=https://api.github.com/repos/%REPO%/releases/latest"

:: Create directories
if not exist "%KRUX_DIR%" mkdir "%KRUX_DIR%"
if not exist "%TEMP_DIR%" mkdir "%TEMP_DIR%"

echo     [~] Checking for latest release...
echo.

:: Get latest release tag and exe download URL
for /f "tokens=*" %%i in ('curl -s %API_URL% ^| findstr /C:"browser_download_url" ^| findstr /C:".exe" ^| findstr /v /C:".pdb"') do (
    set "EXE_URL_RAW=%%i"
)
for /f "tokens=*" %%i in ('curl -s %API_URL% ^| findstr /C:"tag_name"') do (
    set "TAG_RAW=%%i"
)

:: Parse tag name
for /f "tokens=2 delims=:, " %%a in ("%TAG_RAW%") do set "VERSION=%%~a"
set "VERSION=%VERSION:"=%"

:: Parse exe URL
for /f "tokens=2 delims=:," %%a in ("%EXE_URL_RAW%") do set "EXE_URL=%%~a"
set "EXE_URL=%EXE_URL: =%"
set "EXE_URL=%EXE_URL:"=%"

echo     [~] Version: %VERSION%
echo     [~] Downloading KruxExecutor.exe...
echo.

curl -L -# -o "%TEMP_DIR%\KruxExecutor.exe" "%EXE_URL%"
if %errorlevel% neq 0 (
    echo     [-] Failed to download KruxExecutor.exe
    echo     [-] Please check your internet connection and try again
    pause
    exit /b 1
)
echo     [+] KruxExecutor.exe downloaded!
echo.

:: Download Xeno.dll
echo     [~] Downloading Xeno.dll...
for /f "tokens=*" %%i in ('curl -s %API_URL% ^| findstr /C:"browser_download_url" ^| findstr /C:"Xeno.dll"') do (
    set "XENO_RAW=%%i"
)
for /f "tokens=2 delims=:," %%a in ("%XENO_RAW%") do set "XENO_URL=%%~a"
set "XENO_URL=%XENO_URL: =%"
set "XENO_URL=%XENO_URL:"=%"

curl -L -# -o "%TEMP_DIR%\Xeno.dll" "%XENO_URL%"
if %errorlevel% neq 0 (
    echo     [-] Failed to download Xeno.dll
    pause
    exit /b 1
)
echo     [+] Xeno.dll downloaded!
echo.

:: Download libwinpthread-1.dll (Xeno runtime dependency)
echo     [~] Downloading libwinpthread-1.dll...
for /f "tokens=*" %%i in ('curl -s %API_URL% ^| findstr /C:"browser_download_url" ^| findstr /C:"libwinpthread"') do (
    set "PTHREAD_RAW=%%i"
)
for /f "tokens=2 delims=:," %%a in ("%PTHREAD_RAW%") do set "PTHREAD_URL=%%~a"
set "PTHREAD_URL=%PTHREAD_URL: =%"
set "PTHREAD_URL=%PTHREAD_URL:"=%"

curl -L -# -o "%TEMP_DIR%\libwinpthread-1.dll" "%PTHREAD_URL%"
if %errorlevel% neq 0 (
    echo     [-] Failed to download libwinpthread-1.dll
    pause
    exit /b 1
)
echo     [+] libwinpthread-1.dll downloaded!
echo.

:: Copy to install directory
echo     [~] Installing to %KRUX_DIR%...
copy /Y "%TEMP_DIR%\KruxExecutor.exe" "%KRUX_DIR%\KruxExecutor.exe" >nul
copy /Y "%TEMP_DIR%\Xeno.dll" "%KRUX_DIR%\Xeno.dll" >nul
copy /Y "%TEMP_DIR%\libwinpthread-1.dll" "%KRUX_DIR%\libwinpthread-1.dll" >nul

:: Cleanup temp
del /f /q "%TEMP_DIR%\KruxExecutor.exe" >nul 2>&1
del /f /q "%TEMP_DIR%\Xeno.dll" >nul 2>&1
del /f /q "%TEMP_DIR%\libwinpthread-1.dll" >nul 2>&1
rmdir "%TEMP_DIR%" >nul 2>&1

echo     [+] Files installed!
echo.

:: Create desktop shortcut
echo     [~] Creating desktop shortcut...
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%TEMP%\create_shortcut.vbs"
echo sLinkFile = oWS.SpecialFolders("Desktop") ^& "\KRUX Executor.lnk" >> "%TEMP%\create_shortcut.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%TEMP%\create_shortcut.vbs"
echo oLink.TargetPath = "%KRUX_DIR%\KruxExecutor.exe" >> "%TEMP%\create_shortcut.vbs"
echo oLink.WorkingDirectory = "%KRUX_DIR%" >> "%TEMP%\create_shortcut.vbs"
echo oLink.Description = "KRUX Executor" >> "%TEMP%\create_shortcut.vbs"
echo oLink.Save >> "%TEMP%\create_shortcut.vbs"
cscript //nologo "%TEMP%\create_shortcut.vbs" >nul
del /f /q "%TEMP%\create_shortcut.vbs" >nul 2>&1
echo     [+] Desktop shortcut created!
echo.

:: Create start menu shortcut
echo     [~] Creating Start Menu shortcut...
echo Set oWS = WScript.CreateObject("WScript.Shell") > "%TEMP%\create_shortcut2.vbs"
echo sLinkFile = oWS.SpecialFolders("StartMenu") ^& "\Programs\KRUX Executor.lnk" >> "%TEMP%\create_shortcut2.vbs"
echo Set oLink = oWS.CreateShortcut(sLinkFile) >> "%TEMP%\create_shortcut2.vbs"
echo oLink.TargetPath = "%KRUX_DIR%\KruxExecutor.exe" >> "%TEMP%\create_shortcut2.vbs"
echo oLink.WorkingDirectory = "%KRUX_DIR%" >> "%TEMP%\create_shortcut2.vbs"
echo oLink.Description = "KRUX Executor" >> "%TEMP%\create_shortcut2.vbs"
echo oLink.Save >> "%TEMP%\create_shortcut2.vbs"
cscript //nologo "%TEMP%\create_shortcut2.vbs" >nul
del /f /q "%TEMP%\create_shortcut2.vbs" >nul 2>&1
echo     [+] Start Menu shortcut created!
echo.

echo     ================================================================
echo                    KRUX Executor installed successfully!
echo     ================================================================
echo.
echo     Install path:  %KRUX_DIR%
echo     To run:         Double-click KRUX Executor on your Desktop
echo     To uninstall:   Run uninstall.bat or delete %KRUX_DIR%
echo.
echo     Join our Discord: https://discord.gg/krux
echo.

set /p LAUNCH="Launch KRUX now? (Y/N): "
if /i "%LAUNCH%"=="Y" (
    echo     [~] Starting KRUX...
    start "" "%KRUX_DIR%\KruxExecutor.exe"
)

pause
