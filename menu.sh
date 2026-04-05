#!/usr/bin/env bash
set -e

# Colors
RED="\033[1;31m"
GREEN="\033[1;32m"
YELLOW="\033[1;33m"
BLUE="\033[1;34m"
CYAN="\033[1;36m"
MAGENTA="\033[1;35m"
RESET="\033[0m"
BOLD="\033[1m"

REPO_BASE="https://raw.githubusercontent.com/Nattkryper/npm-native-installer/main"

banner() {
    clear
    echo -e "${CYAN}${BOLD}"
    echo "==============================================="
    echo "     NGINX PROXY MANAGER — NATIVE INSTALLER     "
    echo "==============================================="
    echo -e "${RESET}"
}

show_menu() {
    banner
    echo -e "${YELLOW}${BOLD}Main Menu${RESET}"
    echo ""
    echo -e "${GREEN}1)${RESET} Install NPM"
    echo -e "${GREEN}2)${RESET} Update NPM"
    echo -e "${GREEN}3)${RESET} Uninstall NPM"
    echo -e "${GREEN}4)${RESET} Exit"
    echo ""
    echo -ne "${CYAN}Choose [1-4]: ${RESET}"
    read -r CHOICE

    case "$CHOICE" in
        1) bash <(curl -fsSL "$REPO_BASE/scripts/install_core.sh") ;;
        2) bash <(curl -fsSL "$REPO_BASE/scripts/update.sh") ;;
        3) bash <(curl -fsSL "$REPO_BASE/scripts/uninstall.sh") ;;
        4) echo -e "${MAGENTA}Goodbye!${RESET}"; exit 0 ;;
        *) echo -e "${RED}Invalid option!${RESET}"; sleep 1; show_menu ;;
    esac
}

show_menu