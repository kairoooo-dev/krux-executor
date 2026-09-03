@echo off
title KRUX Executor Installer
color 0B
cls
echo.
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@@%%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@#%@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@%@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@%@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@%@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@%@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@%@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@%@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@%@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@%@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@%@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo.
echo                        @@@@@@@@@@@@@@@@@@
echo                     @@@@@@@@@@@@@@@@@@@@@@@@@
echo                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo                  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo                 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo                 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo                 @@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@
echo                  @@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@
echo                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo                     @@@@@@@@@@@@@@@@@@@@@@@@@
echo                       @@@@@@@@@@@@@@@@@@@@@
echo                        @@@@@@@@@@@@@@@@@@@
echo                         @@@@@@@@@@@@@@@@@
echo                          @@@@@@@@@@@@@@@@
echo                           @@@@@@@@@@@@@@@
echo                            @@@@@@@@@@@@@@
echo                             @@@@@@@@@@@@@
echo                              @@@@@@@@@@@@
echo                               @@@@@@@@@@@
echo                                @@@@@@@@@@
echo                                 @@@@@@@@@
echo                                  @@@@@@@@
echo                                   @@@@@@@
echo                                    @@@@@@@
echo                                     @@@@@@
echo                                      @@@@@
echo                                       @@@@
echo                                        @@@
echo                                         @@
echo                                          @
echo.
echo            ##%%@@%%##   K R U X   ##%%@@%%##
echo.
echo   ==============================
echo    KRUX Executor Installer
echo   ==============================
echo.
echo   Installing KRUX...
echo.

powershell -NoProfile -ExecutionPolicy Bypass -Command "try { [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12; $r = Invoke-RestMethod -Uri 'https://api.github.com/repos/kairoooo-dev/krux-executor/releases/latest' -UseBasicParsing; $a = $r.assets | Where-Object { $_.name -like '*.exe' } | Select-Object -First 1; if (-not $a) { throw 'No exe found' }; $d = Join-Path $env:LOCALAPPDATA KRUX; New-Item -ItemType Directory -Path $d -Force | Out-Null; $f = Join-Path $env:TEMP 'KruxExecutor.exe'; $wc = New-Object System.Net.WebClient; $wc.Headers.Add('User-Agent','KRUX'); $wc.DownloadFile($a.browser_download_url, $f); Copy-Item $f (Join-Path $d 'KruxExecutor.exe') -Force; Remove-Item $f -Force; $s = Join-Path ([Environment]::GetFolderPath('Desktop')) 'KRUX Executor.lnk'; $sh = New-Object -ComObject WScript.Shell; $lnk = $sh.CreateShortcut($s); $lnk.TargetPath = Join-Path $d 'KruxExecutor.exe'; $lnk.WorkingDirectory = $d; $lnk.Description = 'KRUX Executor'; $lnk.Save(); $s2 = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk'; $lnk2 = $sh.CreateShortcut($s2); $lnk2.TargetPath = Join-Path $d 'KruxExecutor.exe'; $lnk2.WorkingDirectory = $d; $lnk2.Description = 'KRUX Executor'; $lnk2.Save(); Write-Host ''; Write-Host '  [+] Installed!' -ForegroundColor Green; Write-Host '  [~] Location:' $d -ForegroundColor Cyan; Write-Host '  [~] Desktop shortcut created' -ForegroundColor Cyan; Write-Host ''; Start-Process (Join-Path $d 'KruxExecutor.exe') } catch { Write-Host ''; Write-Host '  [-] Error:' $_.Exception.Message -ForegroundColor Red }"

echo.
echo   Press any key to exit...
pause >nul
