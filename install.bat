@echo off
title KRUX Executor Installer
color 0B
cls
echo.
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@%@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@%@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@%@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@%@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@%@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@%@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@%@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@%@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@%@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
echo   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
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
echo                                    @@@@@@
echo                                     @@@@@
echo                                      @@@@
echo                                       @@@
echo                                        @@
echo                                         @
echo.
echo            ##%%@@%%##   K R U X   ##%%@@%%##
echo.
echo   ==============================
echo    KRUX Executor Installer
echo   ==============================
echo.
echo   Starting installer...
echo.

:: Write install script to temp
set "TEMPDIR=%TEMP%\krux_install"
if not exist "%TEMPDIR%" mkdir "%TEMPDIR%"
set "PSSCRIPT=%TEMPDIR%\install.ps1"

(
echo $ErrorActionPreference = 'Stop'
echo [Console]::OutputEncoding = [System.Text.Encoding]::UTF8
echo.
echo $ESC = [char]27
echo $GREEN  = "${ESC}[92m"
echo $RED    = "${ESC}[91m"
echo $CYAN   = "${ESC}[96m"
echo $BOLD   = "${ESC}[1m"
echo $NC     = "${ESC}[0m"
echo.
echo function Show-Bar {
echo     param^([int]$Pct, [long]$Downloaded, [long]$Total^)
echo     $filled = [math]::Floor^($Pct / 2^)
echo     $empty = 50 - $filled
echo     $bar = ^("#" * $filled^) + ^("-" * $empty^)
echo     $curMB = [math]::Round^($Downloaded / 1MB, 1^)
echo     $totalMB = [math]::Round^($Total / 1MB, 1^)
echo     Write-Host -NoNewline "`r  [$bar] $Pct%%  $curMB/$totalMB MB"
echo }
echo.
echo Write-Host "${CYAN}[~]${NC} Checking for updates..."
echo [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
echo $r = Invoke-RestMethod -Uri "https://api.github.com/repos/kairoooo-dev/krux-executor/releases/latest" -UseBasicParsing
echo $a = $r.assets ^| Where-Object { $_.name -like "*.exe" } ^| Select-Object -First 1
echo if (-not $a^) { Write-Host "${RED}[-] No exe found${NC}"; exit 1 }
echo.
echo $d = Join-Path $env:LOCALAPPDATA KRUX
echo New-Item -ItemType Directory -Path $d -Force ^| Out-Null
echo $f = Join-Path $env:TEMP "KruxExecutor.exe"
echo.
echo Write-Host "${CYAN}[~]${NC} Version: $($r.tag_name^)"
echo Write-Host "${CYAN}[~]${NC} Size: $([math]::Round^($a.size/1MB,1^)^) MB"
echo Write-Host ""
echo Write-Host "${CYAN}[~]${NC} Downloading..."
echo.
echo $wc = New-Object System.Net.WebClient
echo $wc.Headers.Add^("User-Agent", "KRUX"^)
echo $Global:totalBytes = $a.size
echo $Global:currentPct = 0
echo $Global:currentBytes = 0
echo.
echo $ev = Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {
echo     $Global:currentPct = $Event.SourceEventArgs.ProgressPercentage
echo     $Global:currentBytes = [long]$Event.SourceEventArgs.ProgressPercentage * $Global:totalBytes / 100
echo }
echo.
echo $job = Start-Job -ScriptBlock {
echo     param^($url, $out^)
echo     [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
echo     $wc = New-Object System.Net.WebClient
echo     $wc.Headers.Add^("User-Agent", "KRUX"^)
echo     $wc.DownloadFile^($url, $out^)
echo } -ArgumentList $a.browser_download_url, $f
echo.
echo while ^($job.State -eq "Running"^) {
echo     Show-Bar -Pct $Global:currentPct -Downloaded $Global:currentBytes -Total $a.size
echo     Start-Sleep -Milliseconds 200
echo }
echo.
echo Unregister-Event -SourceIdentifier $ev -ErrorAction SilentlyContinue
echo Show-Bar -Pct 100 -Downloaded $a.size -Total $a.size
echo Write-Host ""
echo Write-Host ""
echo.
echo if ^($job.JobStateInfo.State -eq "Failed"^) { Write-Host "${RED}[-] Download failed${NC}"; exit 1 }
echo Write-Host "${GREEN}[+] Download complete!${NC}"
echo.
echo Copy-Item $f ^(Join-Path $d "KruxExecutor.exe"^) -Force
echo Remove-Item $f -Force -ErrorAction SilentlyContinue
echo.
echo $shell = New-Object -ComObject WScript.Shell
echo $lnk = $shell.CreateShortcut^("$([Environment]::GetFolderPath^('Desktop'^)^)\KRUX Executor.lnk"^)
echo $lnk.TargetPath = Join-Path $d "KruxExecutor.exe"
echo $lnk.WorkingDirectory = $d
echo $lnk.Description = "KRUX Executor"
echo $lnk.Save^(^)
echo.
echo $lnk2 = $shell.CreateShortcut^("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk"^)
echo $lnk2.TargetPath = Join-Path $d "KruxExecutor.exe"
echo $lnk2.WorkingDirectory = $d
echo $lnk2.Description = "KRUX Executor"
echo $lnk2.Save^(^)
echo.
echo Write-Host "${GREEN}[+] Installed to $d${NC}"
echo Write-Host "${GREEN}[+] Desktop shortcut created${NC}"
echo Write-Host ""
echo Write-Host "${CYAN}[~]${NC} Starting KRUX..."
echo Start-Process ^(Join-Path $d "KruxExecutor.exe"^)
) > "%PSSCRIPT%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%PSSCRIPT%"

echo.
echo   Press any key to exit...
pause >nul
