@echo off
title KRUX Executor Uninstaller
color 0C
cls
echo.
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @#%@@@@@@%##%%%%%%%%%%%%%%##########%%%%%%%%%%@@@@# @
echo   @#%@      *@%            *%@%        .%@%      #@# @
echo   @#%@  *%@  *@%  %@@%%%@  *%@%  @@@@@  %@%  *%@ #@# @
echo   @#%@  %@@@  *@%  %@%      *%@%  %@%  .%@%  %@@@ #@# @
echo   @#%@  *%@  *@%  %@@%%%@  *%@%  @@@@@  %@%  *%@ #@# @
echo   @#%@      *@%            *%@%        .%@%      #@# @
echo   @#%@@@@@@%##%%%%%%%%%%%%%%##########%%%%%%%%%%@@@@# @
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo.
echo                        ##%%@@%%##   K R U X   ##%%@@%%##
echo.
echo   ==============================
echo    KRUX Executor Uninstaller
echo   ==============================
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { Get-Process -Name 'KruxExecutor' -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue; Start-Sleep -Milliseconds 300; $d = Join-Path $env:LOCALAPPDATA KRUX; if (Test-Path $d) { Remove-Item $d -Recurse -Force; Write-Host '  [+] Removed' $d -ForegroundColor Green } else { Write-Host '  [~] No install found' -ForegroundColor Cyan }; $lnk = Join-Path ([Environment]::GetFolderPath('Desktop')) 'KRUX Executor.lnk'; if (Test-Path $lnk) { Remove-Item $lnk -Force; Write-Host '  [+] Removed desktop shortcut' -ForegroundColor Green }; $s = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk'; if (Test-Path $s) { Remove-Item $s -Force; Write-Host '  [+] Removed start menu shortcut' -ForegroundColor Green }; Write-Host ''; Write-Host '  KRUX has been uninstalled.' -ForegroundColor Green } catch { Write-Host '  [-] Error:' $_.Exception.Message -ForegroundColor Red }"

echo.
echo   Press any key to exit...
pause >nul
