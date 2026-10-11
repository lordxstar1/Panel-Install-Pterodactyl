#!/usr/bin/env bash
# LORDXSTAR Pterodactyl Installer
# Made by LORDXSTAR
# Menu framework with strict input validation and log capture.
set -Eeuo pipefail
IFS=$'\n\t'

APP_NAME="LORDXSTAR"
APP_VERSION="1.0.0"
LOG_DIR="/var/log/lordxstar-installer"
mkdir -p "$LOG_DIR" 2>/dev/null || LOG_DIR="${HOME:-/tmp}/lordxstar-installer-logs"
mkdir -p "$LOG_DIR"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"

if [[ $EUID -ne 0 ]]; then
  printf '\033[1;31m[✗] Please run this installer as root.\033[0m\n'
  printf 'Run: sudo bash install.sh\n'
  exit 1
fi

# ANSI colors
C_RESET=$'\033[0m'
C_CYAN=$'\033[1;36m'
C_MAGENTA=$'\033[1;35m'
C_GREEN=$'\033[1;32m'
C_YELLOW=$'\033[1;33m'
C_RED=$'\033[1;31m'
C_WHITE=$'\033[1;37m'
C_DIM=$'\033[2m'

trap 'rc=$?; printf "\n%s[✗] Installer stopped (exit code %s).%s\n" "$C_RED" "$rc" "$C_RESET"; printf "%sLog: %s%s\n" "$C_DIM" "$LOG_FILE" "$C_RESET"; exit "$rc"' ERR

line() { printf '%s────────────────────────────────────────────────────────%s\n' "$C_CYAN" "$C_RESET"; }
ok() { printf '%s[✓]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
info() { printf '%s[+]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
error() { printf '%s[✗]%s %s\n' "$C_RED" "$C_RESET" "$*"; }
pause() { printf '\n%sPress Enter to continue...%s' "$C_DIM" "$C_RESET"; read -r _ || true; }
header() {
  clear 2>/dev/null || true
  printf '%s' "$C_CYAN"
  cat <<'ART'
 _      ___  ______  ______  _____  ______ _______ _______ _______ _______
 |     |   | |_____] |_____]   |   |_____/ |______ |______ |______    |
 |_____|___| |_____] |_____] __|__ |    \_ |______ |______ ______|    |
ART
  printf '%s%sPTERODACTYL PANEL & WINGS%s\n' "$C_MAGENTA" "$C_WHITE" "$C_RESET"
  printf '%sMade by LORDXSTAR  •  v%s%s\n' "$C_DIM" "$APP_VERSION" "$C_RESET"
  line
}

valid_domain() {
  local value="$1"
  [[ "$value" =~ ^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]
}

run_backend() {
  local mode="$1"
  printf '\n' 
  warn "The upstream installer handles the actual deployment and may display its own prompts."
  warn "This menu cannot safely hide interactive prompts from a separate installer."
  printf 'Continue to the upstream installer for %s? [y/N]: ' "$mode"
  local confirm
  read -r confirm
  [[ "$confirm" =~ ^([yY]|[yY][eE][sS])$ ]] || { warn "Cancelled."; return 0; }

  info "Downloading the upstream installer..."
  if ! curl -fsSL --connect-timeout 15 --max-time 120 https://pterodactyl-installer.se -o /tmp/lordxstar-upstream-installer.sh; then
    error "Could not download the upstream installer. Check network connectivity."
    return 1
  fi
  if ! bash -n /tmp/lordxstar-upstream-installer.sh; then
    error "Downloaded script failed shell syntax validation; refusing to run it."
    rm -f /tmp/lordxstar-upstream-installer.sh
    return 1
  fi
  {
    printf '\n===== LORDXSTAR backend start: %s =====\n' "$(date -Is)"
    bash /tmp/lordxstar-upstream-installer.sh
    rc=$?
    printf '\n===== backend exit code: %s =====\n' "$rc"
    exit "$rc"
  } 2>&1 | tee -a "$LOG_FILE"
}

while true; do
  header
  printf '%sSELECT AN OPTION%s\n\n' "$C_YELLOW" "$C_RESET"
  printf '  %s[1]%s Install Panel\n' "$C_WHITE" "$C_RESET"
  printf '  %s[2]%s Install Wings\n' "$C_WHITE" "$C_RESET"
  printf '  %s[3]%s Install Panel + Wings\n' "$C_WHITE" "$C_RESET"
  printf '  %s[4]%s Uninstaller Hub (not enabled in this build)\n' "$C_WHITE" "$C_RESET"
  printf '  %s[0]%s Exit Installer\n\n' "$C_RED" "$C_RESET"
  line
  printf '%sChoose a category [0-4]: %s' "$C_YELLOW" "$C_RESET"
  choice=""
  IFS= read -r choice || true

  case "$choice" in
    1) run_backend "Panel"; pause ;;
    2) run_backend "Wings"; pause ;;
    3) run_backend "Panel + Wings"; pause ;;
    4) warn "Uninstaller is disabled until a backup-aware removal module is implemented."; pause ;;
    0) ok "Goodbye. Thanks for using LORDXSTAR Installer."; exit 0 ;;
    *) error "Galat Option! Please select a valid option (0-4)."; sleep 1 ;;
  esac
done
