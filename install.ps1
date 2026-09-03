$ErrorActionPreference = 'Stop'

$ESC = [char]27
$RED    = "${ESC}[91m"
$GREEN  = "${ESC}[92m"
$YELLOW = "${ESC}[93m"
$BLUE   = "${ESC}[94m"
$CYAN   = "${ESC}[96m"
$BOLD   = "${ESC}[1m"
$NC     = "${ESC}[0m"

$CHECK = "${GREEN}[+]${NC}"
$CROSS = "${RED}[-]${NC}"
$INFO  = "${CYAN}[~]${NC}"

$REPO   = "kairoooo-dev/krux-executor"
$INSTALL_DIR = "$env:LOCALAPPDATA\KRUX"
$EXE_NAME    = "KruxExecutor.exe"

function Write-Section {
    param([string]$Message)
    Write-Host ""
    Write-Host "${BOLD}${CYAN}==> $Message${NC}"
}

function Write-Step {
    param([string]$Message, [scriptblock]$Action)
    Write-Host -NoNewline "${CYAN}[...]${NC} $Message`r"
    try {
        & $Action | Out-Null
        Write-Host "`r${CHECK} $Message${NC}    "
    } catch {
        Write-Host "`r${CROSS} $Message${NC}    "
        Write-Host "${RED}Error: $($_.Exception.Message)${NC}"
        exit 1
    }
}

function Show-Banner {
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
    Write-Host "${BLUE}  = [ KRUX Executor Installer ] =${NC}"
    Write-Host "${CYAN}  Developed by Kruz2Cold${NC}"
    Write-Host ""
}

function Get-LatestRelease {
    Write-Host -NoNewline "${CYAN}[...]${NC} Fetching latest release...`r"
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $headers = @{ "User-Agent" = "KRUX-Installer/1.0" }
        $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$REPO/releases/latest" -Headers $headers -UseBasicParsing
        $asset = $release.assets | Where-Object { $_.name -like "*.exe" } | Select-Object -First 1
        if (-not $asset) {
            Write-Host "`r${CROSS} No executable found in latest release${NC}    "
            Write-Host "${YELLOW}Download manually: https://github.com/$REPO/releases${NC}"
            exit 1
        }
        Write-Host "`r${CHECK} Latest release: $($release.tag_name)${NC}    "
        return @{ Url = $asset.browser_download_url; Name = $asset.name; Version = $release.tag_name }
    } catch {
        Write-Host "`r${CROSS} Failed to fetch release${NC}    "
        Write-Host "${RED}Error: $($_.Exception.Message)${NC}"
        Write-Host "${YELLOW}Download manually: https://github.com/$REPO/releases${NC}"
        exit 1
    }
}

# ═══ MAIN ═══
Show-Banner

Write-Section "Preparing system"
Write-Step "Stopping KRUX processes" {
    Get-Process -Name "KruxExecutor" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 200
}
Write-Step "Stopping Roblox processes" {
    Get-Process -Name "RobloxPlayerBeta" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 200
}

Write-Section "Removing old installation"
if (Test-Path $INSTALL_DIR) {
    Write-Step "Removing $INSTALL_DIR" {
        Remove-Item -Path $INSTALL_DIR -Recurse -Force
    }
} else {
    Write-Host "${INFO} No previous installation found"
}

Write-Section "Fetching latest release"
$release = Get-LatestRelease

Write-Section "Downloading KRUX Executor"
$tempFile = Join-Path $env:TEMP "KruxExecutor_$([System.IO.Path]::GetRandomFileName()).exe"
Write-Step "Downloading $($release.Name)" {
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    $wc = New-Object System.Net.WebClient
    $wc.Headers.Add("User-Agent", "KRUX-Installer/1.0")
    $wc.DownloadFile($release.Url, $tempFile)
}
Write-Step "Verifying download" {
    if (-not (Test-Path $tempFile)) { throw "File not found after download" }
    $size = (Get-Item $tempFile).Length
    if ($size -lt 1MB) { throw "File too small ($size bytes)" }
}

Write-Section "Installing KRUX Executor"
New-Item -ItemType Directory -Path $INSTALL_DIR -Force | Out-Null
Write-Step "Copying executor" {
    Copy-Item -Path $tempFile -Destination "$INSTALL_DIR\$EXE_NAME" -Force
}
Write-Step "Cleaning up" {
    Remove-Item -Path $tempFile -Force -ErrorAction SilentlyContinue
}
Write-Step "Creating shortcut" {
    $shortcutPath = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk"
    $shell = New-Object -ComObject WScript.Shell
    $shortcut = $shell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = "$INSTALL_DIR\$EXE_NAME"
    $shortcut.WorkingDirectory = $INSTALL_DIR
    $shortcut.Description = "KRUX Executor"
    $shortcut.Save()
}

Write-Host ""
Write-Host "${GREEN}${BOLD}  Installation complete!${NC}"
Write-Host ""
Write-Host "${INFO} Installed to: ${BOLD}$INSTALL_DIR\$EXE_NAME${NC}"
Write-Host ""

$launch = Read-Host "${CYAN}  Launch KRUX now? [Y/n]${NC}"
if ($launch -ne 'n' -and $launch -ne 'N') {
    Write-Host "${INFO} Starting KRUX..."
    Start-Process -FilePath "$INSTALL_DIR\$EXE_NAME"
} else {
    Write-Host "${INFO} Run ${BOLD}$INSTALL_DIR\$EXE_NAME${NC} to start."
}
