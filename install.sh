#!/usr/bin/env bash
# ──────────────────────────────────────────────────────────────────────────────
# KRUX Executor Installer
# Style inspired by Opiumware installer by @norbyv1
# Developed by Kruz2Cold
# ──────────────────────────────────────────────────────────────────────────────
set -euo pipefail
IFS=$'\n\t'

RED='\033[91m'
GREEN='\033[92m'
YELLOW='\033[93m'
BLUE='\033[94m'
CYAN='\033[96m'
BOLD='\033[1m'
NC='\033[0m'

CHECK="${GREEN}[+]${NC}"
CROSS="${RED}[-]${NC}"
INFO="${CYAN}[~]${NC}"
WARN="${YELLOW}[!]${NC}"

REPO="kairoooo-dev/krux-executor"
INSTALL_DIR="$LOCALAPPDATA/KRUX"
EXE_NAME="KruxExecutor.exe"

section() {
    echo
    echo -e "${BOLD}${CYAN}==> $1${NC}"
}

run_step() {
    local msg="$1"
    shift
    echo -ne "${CYAN}[...]${NC} $msg\r"
    if "$@" >/dev/null 2>&1; then
        printf "\r\033[K${GREEN}${CHECK} %s${NC}\n" "$msg"
    else
        printf "\r\033[K${RED}${CROSS} %s${NC}\n" "$msg"
        exit 1
    fi
}

banner() {
    clear
    echo -e "${BOLD}${CYAN}"
    cat <<'EOF'
     ██╗  ██╗██╗   ██╗██████╗ ███████╗██████╗ ████████╗
     ██║ ██╔╝██║   ██║██╔══██╗██╔════╝██╔══██╗╚══██╔══╝
     █████╔╝ ██║   ██║██████╔╝███████╗██████╔╝   ██║
     ██╔═██╗ ██║   ██║██╔══██╗╚════██║██╔═══╝    ██║
     ██║  ██╗╚██████╔╝██║  ██║███████║██║        ██║
     ╚═╝  ╚═╝ ╚═════╝ ╚═╝  ╚═╝╚══════╝╚═╝        ╚═╝
EOF
    echo -e "${NC}"
    echo -e "${BLUE}=[ KRUX Executor Installer ]=${NC}"
    echo -e "${CYAN}Developed by Kruz2Cold${NC}\n"
}

main() {
    banner

    # ── Detect install location ───────────────────────────────────────────
    if [ -n "${LOCALAPPDATA:-}" ]; then
        INSTALL_DIR="$LOCALAPPDATA/KRUX"
    elif [ -d "$HOME/AppData/Local" ]; then
        INSTALL_DIR="$HOME/AppData/Local/KRUX"
    else
        INSTALL_DIR="$HOME/.krux"
    fi
    echo -e "${INFO} Installing to ${BOLD}$INSTALL_DIR${NC}"

    TEMP="$(mktemp -d)"

    # ── Kill running processes ────────────────────────────────────────────
    section "Preparing system"
    run_step "Stopping KRUX processes" bash -c 'taskkill /F /IM KruxExecutor.exe 2>/dev/null || true'
    run_step "Stopping Roblox processes" bash -c 'taskkill /F /IM RobloxPlayerBeta.exe 2>/dev/null || true'

    # ── Remove old install ────────────────────────────────────────────────
    section "Removing old installation"
    if [ -d "$INSTALL_DIR" ]; then
        run_step "Removing old files" rm -rf "$INSTALL_DIR"
    else
        echo -e "${INFO} No previous installation found"
    fi

    # ── Fetch latest release ──────────────────────────────────────────────
    section "Fetching latest release"
    echo -ne "${CYAN}[...]${NC} Getting release info...\r"
    RELEASE_JSON=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest")
    TAG=$(echo "$RELEASE_JSON" | grep -o '"tag_name":"[^"]*"' | head -1 | cut -d'"' -f4)
    DOWNLOAD_URL=$(echo "$RELEASE_JSON" | grep -o '"browser_download_url":"[^"]*\.exe"' | head -1 | cut -d'"' -f4)

    if [ -z "$DOWNLOAD_URL" ]; then
        printf "\r\033[K${RED}${CROSS} No download found in latest release${NC}\n"
        exit 1
    fi
    printf "\r\033[K${GREEN}${CHECK} Latest release: %s${NC}\n" "$TAG"

    # ── Download ──────────────────────────────────────────────────────────
    section "Downloading KRUX Executor"
    run_step "Downloading $EXE_NAME" bash -c "curl -# -L '$DOWNLOAD_URL' -o '$TEMP/$EXE_NAME'"

    # ── Install ───────────────────────────────────────────────────────────
    section "Installing KRUX Executor"
    run_step "Creating install directory" mkdir -p "$INSTALL_DIR"
    run_step "Copying executor" cp "$TEMP/$EXE_NAME" "$INSTALL_DIR/$EXE_NAME"
    run_step "Cleaning up" rm -rf "$TEMP"

    # ── Done ──────────────────────────────────────────────────────────────
    echo
    echo -e "${GREEN}${BOLD}Installation complete!${NC}"
    echo
    echo -e "${INFO} Installed to: ${BOLD}$INSTALL_DIR/$EXE_NAME${NC}"
    echo

    # ── Launch ────────────────────────────────────────────────────────────
    read -rp "$(echo -e ${CYAN}Launch KRUX now? [Y/n] ${NC})" choice
    if [[ "${choice,,}" != "n" ]]; then
        echo -e "${INFO} Starting KRUX Executor..."
        start "" "$INSTALL_DIR/$EXE_NAME" 2>/dev/null || "$INSTALL_DIR/$EXE_NAME" &
    else
        echo -e "${INFO} Run ${BOLD}$INSTALL_DIR/$EXE_NAME${NC} to start."
    fi
}

main
