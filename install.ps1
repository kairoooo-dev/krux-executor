$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$ESC = [char]27
$GREEN  = "${ESC}[92m"
$RED    = "${ESC}[91m"
$CYAN   = "${ESC}[96m"
$BOLD   = "${ESC}[1m"
$NC     = "${ESC}[0m"

function Show-Bar {
    param([int]$Pct, [int]$Downloaded, [int]$Total)
    $filled = [math]::Floor($Pct / 2)
    $empty = 50 - $filled
    $bar = ("#" * $filled) + ("-" * $empty)
    $curMB = [math]::Round($Downloaded / 1MB, 1)
    $totalMB = [math]::Round($Total / 1MB, 1)
    Write-Host -NoNewline "`r  [$bar] $Pct%  $curMB/$totalMB MB"
}

Clear-Host
Write-Host ""
Write-Host "${BOLD}${CYAN}  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@@%@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@%@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@%@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@@@%@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@%@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@%@@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@%@@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@@%@@@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@@@%@@%@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host ""
Write-Host "${BOLD}${CYAN}                        @@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                     @@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                 @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                 @@@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                  @@@@@@@@@%@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                   @@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                     @@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                       @@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                        @@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                         @@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                          @@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                           @@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                            @@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                             @@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                              @@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                               @@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                                @@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                                 @@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                                  @@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                                   @@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                                    @@@@@@${NC}"
Write-Host "${BOLD}${CYAN}                                     @@@@@${NC}"
Write-Host "${BOLD}${CYAN}                                      @@@@${NC}"
Write-Host "${BOLD}${CYAN}                                       @@@${NC}"
Write-Host "${BOLD}${CYAN}                                        @@${NC}"
Write-Host "${BOLD}${CYAN}                                         @${NC}"
Write-Host ""
Write-Host "${BOLD}${CYAN}            ##%%@@%%##   K R U X   ##%%@@%%##${NC}"
Write-Host ""
Write-Host "${CYAN}  = [ KRUX Executor Installer ] =${NC}"
Write-Host ""

# ═══ MAIN ═══
Write-Host "${CYAN}[~]${NC} Checking for updates..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$r = Invoke-RestMethod -Uri "https://api.github.com/repos/kairoooo-dev/krux-executor/releases/latest" -UseBasicParsing
$a = $r.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
if (-not $a) { Write-Host "${RED}[-] No exe found${NC}"; exit 1 }

$d = Join-Path $env:LOCALAPPDATA KRUX
New-Item -ItemType Directory -Path $d -Force | Out-Null
$f = Join-Path $env:TEMP "KruxExecutor.exe"

Write-Host "${CYAN}[~]${NC} Version: $($r.tag_name)"
Write-Host "${CYAN}[~]${NC} Size: $([math]::Round($a.size/1MB,1)) MB"
Write-Host ""

# Download with progress
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "KRUX")

$done = $false
$lastPct = -1

$downloadJob = {
    param($wc, $url, $out)
    $wc.DownloadFile($url, $out)
}

$eventData = Register-ObjectEvent -InputObject $wc -EventName DownloadProgressChanged -Action {
    $Global:currentPct = $Event.SourceEventArgs.ProgressPercentage
    $Global:currentBytes = $Event.SourceEventArgs.ProgressPercentage * $Global:totalBytes / 100
}

$Global:totalBytes = $a.size
$Global:currentPct = 0
$Global:currentBytes = 0

$job = Start-Job -ScriptBlock {
    param($url, $out)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "KRUX")
    $wc.DownloadFile($url, $out)
} -ArgumentList $a.browser_download_url, $f

while ($job.State -eq "Running") {
    $pct = $Global:currentPct
    $bytes = $Global:currentBytes
    Show-Bar -Pct $pct -Downloaded ([int]$bytes) -Total $a.size
    Start-Sleep -Milliseconds 200
}

Unregister-Event -SourceIdentifier $eventData -ErrorAction SilentlyContinue

Show-Bar -Pct 100 -Downloaded $a.size -Total $a.size
Write-Host ""
Write-Host ""

if ($job.JobStateInfo.State -eq "Failed") {
    Write-Host "${RED}[-] Download failed${NC}"
    exit 1
}

Write-Host "${GREEN}[+] Download complete!${NC}"

# Install
Copy-Item $f (Join-Path $d "KruxExecutor.exe") -Force
Remove-Item $f -Force -ErrorAction SilentlyContinue

# Desktop shortcut
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut("$([Environment]::GetFolderPath('Desktop'))\KRUX Executor.lnk")
$lnk.TargetPath = Join-Path $d "KruxExecutor.exe"
$lnk.WorkingDirectory = $d
$lnk.Description = "KRUX Executor"
$lnk.Save()

# Start Menu shortcut
$lnk2 = $shell.CreateShortcut("$env:APPDATA\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk")
$lnk2.TargetPath = Join-Path $d "KruxExecutor.exe"
$lnk2.WorkingDirectory = $d
$lnk2.Description = "KRUX Executor"
$lnk2.Save()

Write-Host "${GREEN}[+] Installed to $d${NC}"
Write-Host "${GREEN}[+] Desktop shortcut created${NC}"
Write-Host ""
Write-Host "${CYAN}[~]${NC} Starting KRUX..."
Start-Process (Join-Path $d "KruxExecutor.exe")
