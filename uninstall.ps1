#Requires -Version 5.1
<#
.SYNOPSIS
    KRUX Executor Uninstaller
.DESCRIPTION
    Removes KRUX Executor from your system.
.NOTES
    Developed by Kruz2Cold
#>

$ErrorActionPreference = 'Stop'

$ESC = [char]27
$RED    = "${ESC}[91m"
$GREEN  = "${ESC}[92m"
$YELLOW = "${ESC}[93m"
$CYAN   = "${ESC}[96m"
$BOLD   = "${ESC}[1m"
$NC     = "${ESC}[0m"

$CHECK = "${GREEN}[+]${NC}"
$CROSS = "${RED}[-]${NC}"
$INFO  = "${CYAN}[~]${NC}"
$WARN  = "${YELLOW}[!]${NC}"

$INSTALL_DIR = "$env:LOCALAPPDATA\KRUX"
$SHORTCUT    = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\KRUX Executor.lnk"

Clear-Host
Write-Host "${BOLD}${RED}"
@'
     .:#%@@@%#:.
     %@       @%
     @%  %@%  %@
     @%  %@%  %@
     %@       @%
     ':%#%@%@#%:'

     K R U X

'@ | Write-Host
Write-Host "${NC}"
Write-Host "${RED}=[ KRUX Executor Uninstaller ]=${NC}"
Write-Host ""

# Kill processes
Write-Host -NoNewline "${CYAN}[...]${NC} Stopping KRUX...`r"
Get-Process -Name "KruxExecutor" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Milliseconds 300
Write-Host "`r${CHECK} Stopped KRUX${NC}    "

# Remove install directory
if (Test-Path $INSTALL_DIR) {
    Write-Host -NoNewline "${CYAN}[...]${NC} Removing $INSTALL_DIR...`r"
    Remove-Item -Path $INSTALL_DIR -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $INSTALL_DIR) {
        Write-Host "`r${CROSS} Failed to remove $INSTALL_DIR (try running as Admin)${NC}"
    } else {
        Write-Host "`r${CHECK} Removed $INSTALL_DIR${NC}    "
    }
} else {
    Write-Host "${INFO} No install directory found"
}

# Remove shortcut
if (Test-Path $SHORTCUT) {
    Write-Host -NoNewline "${CYAN}[...]${NC} Removing Start Menu shortcut...`r"
    Remove-Item -Path $SHORTCUT -Force
    Write-Host "`r${CHECK} Removed shortcut${NC}    "
} else {
    Write-Host "${INFO} No shortcut found"
}

Write-Host ""
Write-Host "${GREEN}${BOLD}KRUX has been uninstalled.${NC}"
Write-Host ""
Read-Host "Press Enter to exit"
