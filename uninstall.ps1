$ErrorActionPreference = 'Stop'

$ESC = [char]27
$RED    = "${ESC}[91m"
$GREEN  = "${ESC}[92m"
$CYAN   = "${ESC}[96m"
$BOLD   = "${ESC}[1m"
$NC     = "${ESC}[0m"

$CHECK = "${GREEN}[+]${NC}"
$CROSS = "${RED}[-]${NC}"
$INFO  = "${CYAN}[~]${NC}"

$INSTALL_DIR = "$env:LOCALAPPDATA\KRUX"
$SHORTCUT    = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk"

Clear-Host
Write-Host ""
Write-Host "${BOLD}${RED}  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host "${BOLD}${RED}  @#%@@@@@@%##%%%%%%%%%%%%%%##########%%%%%%%%%%@@@@# @${NC}"
Write-Host "${BOLD}${RED}  @#%@      *@%            *%@%        .%@%      #@# @${NC}"
Write-Host "${BOLD}${RED}  @#%@  *%@  *@%  %@@%%%@  *%@%  @@@@@  %@%  *%@ #@# @${NC}"
Write-Host "${BOLD}${RED}  @#%@  %@@@  *@%  %@%      *%@%  %@%  .%@%  %@@@ #@# @${NC}"
Write-Host "${BOLD}${RED}  @#%@  *%@  *@%  %@@%%%@  *%@%  @@@@@  %@%  *%@ #@# @${NC}"
Write-Host "${BOLD}${RED}  @#%@      *@%            *%@%        .%@%      #@# @${NC}"
Write-Host "${BOLD}${RED}  @#%@@@@@@%##%%%%%%%%%%%%%%##########%%%%%%%%%%@@@@# @${NC}"
Write-Host "${BOLD}${RED}  @@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@${NC}"
Write-Host ""
Write-Host "${BOLD}${RED}       ##%%@@%%##  K R U X  ##%%@@%%##${NC}"
Write-Host ""
Write-Host "${RED}  = [ KRUX Executor Uninstaller ] =${NC}"
Write-Host ""

Write-Host -NoNewline "${CYAN}[...]${NC} Stopping KRUX...`r"
Get-Process -Name "KRUX" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300
Write-Host "`r${CHECK} Stopped KRUX${NC}    "

if (Test-Path $INSTALL_DIR) {
    Write-Host -NoNewline "${CYAN}[...]${NC} Removing $INSTALL_DIR...`r"
    Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $INSTALL_DIR) {
        Write-Host "`r${CROSS} Failed (run as Admin)${NC}"
    } else {
        Write-Host "`r${CHECK} Removed $INSTALL_DIR${NC}    "
    }
} else {
    Write-Host "${INFO} No install directory found"
}

if (Test-Path $SHORTCUT) {
    Write-Host -NoNewline "${CYAN}[...]${NC} Removing shortcut...`r"
    Remove-Item -Path $SHORTCUT -Force
    Write-Host "`r${CHECK} Removed shortcut${NC}    "
}

Write-Host ""
Write-Host "${GREEN}${BOLD}  KRUX has been uninstalled.${NC}"
Write-Host ""
Read-Host "  Press Enter to exit"
