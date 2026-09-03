$ErrorActionPreference = 'Stop'

$ESC = [char]27
$GREEN  = "${ESC}[92m"
$RED    = "${ESC}[91m"
$CYAN   = "${ESC}[96m"
$BOLD   = "${ESC}[1m"
$NC     = "${ESC}[0m"

$REPO   = "kairoooo-dev/krux-executor"
$INSTALL_DIR = "$env:LOCALAPPDATA\KRUX"
$EXE_NAME    = "KruxExecutor.exe"

Clear-Host
Write-Host ""
Write-Host "${BOLD}${CYAN}  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${CYAN}  @#%@@@@@@%##%%%%%%%%%%%%%%##########%%%%%%%%%%@@@@# @${NC}"
Write-Host "${BOLD}${CYAN}  @#%@      *@%            *%@%        .%@%      #@# @${NC}"
Write-Host "${BOLD}${CYAN}  @#%@  *%@  *@%  %@@%%%@  *%@%  @@@@@  %@%  *%@ #@# @${NC}"
Write-Host "${BOLD}${CYAN}  @#%@  %@@@  *@%  %@%      *%@%  %@%  .%@%  %@@@ #@# @${NC}"
Write-Host "${BOLD}${CYAN}  @#%@  *%@  *@%  %@@%%%@  *%@%  @@@@@  %@%  *%@ #@# @${NC}"
Write-Host "${BOLD}${CYAN}  @#%@      *@%            *%@%        .%@%      #@# @${NC}"
Write-Host "${BOLD}${CYAN}  @#%@@@@@@%##%%%%%%%%%%%%%%##########%%%%%%%%%%@@@@# @${NC}"
Write-Host "${BOLD}${CYAN}  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host ""
Write-Host "${BOLD}${CYAN}       ##%%@@%%##  K R U X  ##%%@@%%##${NC}"
Write-Host ""

# Kill old processes
Write-Host "${CYAN}[~]${NC} Cleaning up..."
Get-Process -Name "KruxExecutor" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300

# Remove old
if (Test-Path $INSTALL_DIR) {
    Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
}

# Fetch release
Write-Host "${CYAN}[~]${NC} Fetching release..."
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$headers = @{ "User-Agent" = "KRUX" }
$release = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest" -Headers $headers -UseBasicParsing
$asset = $release.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
if (-not $asset) { Write-Host "${RED}[-] No exe found${NC}"; exit 1 }

# Download
Write-Host "${CYAN}[~]${NC} Downloading $($release.tag_name)..."
$tempFile = Join-Path $env:TEMP "KruxExecutor.exe"
$wc = New-Object System.Net.WebClient
$wc.Headers.Add("User-Agent", "KRUX")
$wc.DownloadFile($asset.browser_download_url, $tempFile)

# Install
New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
Copy-Item -Path $tempFile -Destination "$INSTALL_DIR\$EXE_NAME" -Force
Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue

# Desktop shortcut
$desktopPath = [Environment]::GetFolderPath("Desktop")
$shell = New-Object -ComObject WScript.Shell
$lnk = $shell.CreateShortcut("$desktopPath\KRUX Executor.lnk")
$lnk.TargetPath = "$INSTALL_DIR\$EXE_NAME"
$lnk.WorkingDirectory = $INSTALL_DIR
$lnk.Description = "KRUX Executor"
$lnk.Save()

# Start Menu shortcut
$startPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk"
$lnk2 = $shell.CreateShortcut($startPath)
$lnk2.TargetPath = "$INSTALL_DIR\$EXE_NAME"
$lnk2.WorkingDirectory = $INSTALL_DIR
$lnk2.Description = "KRUX Executor"
$lnk2.Save()

Write-Host ""
Write-Host "${GREEN}${BOLD}  [+] Installed!${NC}"
Write-Host "${CYAN}[~]${NC} $INSTALL_DIR\$EXE_NAME"
Write-Host "${CYAN}[~]${NC} Desktop shortcut created"
Write-Host ""

# Auto-start KRUX
Write-Host "${CYAN}[~]${NC} Starting KRUX..."
Start-Process -FilePath "$INSTALL_DIR\$EXE_NAME"
