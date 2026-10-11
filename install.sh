#!/usr/bin/env bash
# LORDXSTAR Pterodactyl Installer
# Made by LORDXSTAR
set -Eeuo pipefail
IFS=$'\n\t'
umask 077

APP_VERSION="1.0.1"
LOG_DIR="/var/log/lordxstar-installer"
LOG_FILE=""
C_RESET=$'\033[0m'; C_CYAN=$'\033[1;36m'; C_MAGENTA=$'\033[1;35m'
C_GREEN=$'\033[1;32m'; C_YELLOW=$'\033[1;33m'; C_RED=$'\033[1;31m'; C_WHITE=$'\033[1;37m'; C_DIM=$'\033[2m'

if [[ ! -t 1 ]]; then
  C_RESET=''; C_CYAN=''; C_MAGENTA=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_WHITE=''; C_DIM=''
fi

if [[ $EUID -ne 0 ]]; then
  printf '%s[✗] Please run as root: sudo -i, then run the installer.%s\n' "$C_RED" "$C_RESET"
  exit 1
fi
mkdir -p "$LOG_DIR"
chmod 700 "$LOG_DIR"
LOG_FILE="$LOG_DIR/install-$(date +%Y%m%d-%H%M%S).log"
touch "$LOG_FILE"; chmod 600 "$LOG_FILE"
exec 3>>"$LOG_FILE"

on_error() {
  local rc=$?
  printf '\n%s[✗] An operation failed (exit %s).%s\n' "$C_RED" "$rc" "$C_RESET"
  printf '%s[!] Details are saved in: %s%s\n' "$C_YELLOW" "$LOG_FILE" "$C_RESET"
}
trap on_error ERR

line() { printf '%s────────────────────────────────────────────────────────%s\n' "$C_CYAN" "$C_RESET"; }
ok() { printf '%s[✓]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
info() { printf '%s[+]%s %s\n' "$C_CYAN" "$C_RESET" "$*"; }
warn() { printf '%s[!]%s %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
error() { printf '%s[✗]%s %s\n' "$C_RED" "$C_RESET" "$*"; }
pause() { printf '\n%sPress Enter to return to menu...%s' "$C_DIM" "$C_RESET"; read -r _ || true; }

header() {
  clear 2>/dev/null || true
  printf '%s' "$C_CYAN"
  cat <<'ART'
 _     ___  ____  ____  _   _  ____ _____  ____ _____  ____  ____
| |   / _ \|  _ \|  _ \| | | |/ ___|_   _|/ ___|_   _|/ ___||  _ \
| |  | | | | |_) | | | | | | | |     | |  \___ \ | |  \___ \| |_) |
| |__| |_| |  _ <| |_| | |_| | |___  | |   ___) || |   ___) |  __/
|_____\___/|_| \_\____/ \___/ \____| |_|  |____/ |_|  |____/|_|
ART
  printf '%sPTERODACTYL PANEL & WINGS%s\n' "$C_MAGENTA" "$C_RESET"
  printf '%sVersion %s • Made by LORDXSTAR%s\n' "$C_DIM" "$APP_VERSION" "$C_RESET"
  line
}

valid_domain() {
  local value="${1,,}"
  [[ ${#value} -le 253 && "$value" =~ ^([a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z]{2,63}$ ]]
}
ask_domain() {
  local value
  while true; do
    printf '%sPanel domain (e.g. panel.example.com): %s' "$C_WHITE" "$C_RESET"
    read -r value || value=""
    value="${value,,}"
    if valid_domain "$value"; then REPLY="$value"; return 0; fi
    error "Galat Domain! Enter a hostname only; do not include https:// or a path."
  done
}
ask_choice() {
  local choice
  while true; do
    printf '\n%sChoose a category [0-4]: %s' "$C_YELLOW" "$C_RESET"
    read -r choice || choice=""
    case "$choice" in
      0|1|2|3|4) REPLY="$choice"; return 0 ;;
      *) error "Galat Option! Please select a valid option (0-4)." ;;
    esac
  done
}
check_os() {
  [[ -r /etc/os-release ]] || { error "Cannot detect operating system."; return 1; }
  . /etc/os-release
  if [[ "$ID" != "ubuntu" || ( "${VERSION_ID:-}" != "22.04" && "${VERSION_ID:-}" != "24.04" ) ]]; then
    error "Supported OS: Ubuntu 22.04 LTS and 24.04 LTS. Detected: ${PRETTY_NAME:-unknown}"
    return 1
  fi
  ok "Detected $PRETTY_NAME"
  if ! command -v curl >/dev/null 2>&1; then
    info "Installing required download utility"
    apt-get update >>"$LOG_FILE" 2>&1
    apt-get install -y curl ca-certificates openssl >>"$LOG_FILE" 2>&1
  fi
  command -v openssl >/dev/null 2>&1 || { apt-get update >>"$LOG_FILE" 2>&1; apt-get install -y openssl >>"$LOG_FILE" 2>&1; }
}
random_secret() { openssl rand -hex 18; }

progress_run() {
  local label="$1"; shift
  local pid rc i=0 spin='|/-\\'
  info "$label"
  ("$@" >>"$LOG_FILE" 2>&1) &
  pid=$!
  while kill -0 "$pid" 2>/dev/null; do
    printf '\r  %s[%s]%s %s' "$C_CYAN" "${spin:i%4:1}" "$C_RESET" "$label"
    i=$((i + 1))
    sleep 0.25
  done
  if wait "$pid"; then
    printf '\r  %s[✓]%s %s\n' "$C_GREEN" "$C_RESET" "$label"
  else
    rc=$?
    printf '\r  %s[✗]%s %s\n' "$C_RED" "$C_RESET" "$label"
    printf '%sLast log lines:%s\n' "$C_YELLOW" "$C_RESET"
    tail -n 18 "$LOG_FILE" || true
    return "$rc"
  fi
}

run_panel_backend() {
  local mode="$1" panel_domain="$2"
  local wings_domain="node.${panel_domain#*.}"
  local admin_email="admin@${panel_domain#*.}"
  local admin_user="lordxstar"
  local admin_pass
  admin_pass="$(random_secret)"
  local installer="/tmp/lordxstar-backend-$$.sh"

  # DNS must already resolve before requesting Let's Encrypt certificates.
  if ! command -v getent >/dev/null 2>&1 || ! getent ahosts "$panel_domain" >/dev/null 2>&1; then
    warn "DNS lookup for $panel_domain did not resolve. SSL setup may fail."
    warn "Make sure the domain points to this VPS before continuing."
    printf 'Continue anyway? [y/N]: '
    local confirm; read -r confirm || confirm=""
    [[ "$confirm" =~ ^[Yy]$ ]] || return 0
  fi

  export PANEL_DOMAIN="$panel_domain"
  export LE_EMAIL="$admin_email"
  export TIMEZONE="Asia/Kolkata"
  export WINGS_DOMAIN="$wings_domain"
  export DB_PASSWORD="$(random_secret)"
  if [[ "$mode" == "panel" ]]; then export NO_WINGS=1; else unset NO_WINGS || true; fi

  line
  info "Deployment mode: $mode"
  info "Panel domain: $panel_domain"
  info "Administrator email: $admin_email"
  info "Backend output is hidden; detailed output is stored in the protected log."
  if ! progress_run "Downloading installation backend" curl -fsSL --connect-timeout 15 --max-time 120 "https://raw.githubusercontent.com/2hoch1/pterodactyl-installer/main/get.sh" -o "$installer"; then
    rm -f "$installer"
    error "Backend download failed. Check network access."
    return 1
  fi
  chmod 700 "$installer"
  if ! bash -n "$installer" >>"$LOG_FILE" 2>&1; then
    rm -f "$installer"
    error "Downloaded backend failed syntax validation; refusing to execute."
    return 1
  fi
  if ! progress_run "Installing Pterodactyl components" bash -c 'bash "$1" --yes' _ "$installer"; then
    rm -f "$installer"
    error "Installation failed. Review the log file before retrying."
    return 1
  fi
  rm -f "$installer"

  # Create an administrator using the Panel's supported Artisan command.
  if [[ -d /var/www/pterodactyl && -f /var/www/pterodactyl/artisan ]]; then
    if ! progress_run "Creating administrator account" bash -c 'cd /var/www/pterodactyl && php artisan p:user:make --email="$1" --username="$2" --name-first="LORDXSTAR" --name-last="Admin" --password="$3" --admin=1' _ "$admin_email" "$admin_user" "$admin_pass"; then
      warn "Automatic administrator creation was not confirmed."
      admin_pass=""
    fi
  else
    warn "Panel directory not found; cannot verify administrator creation."
    admin_pass=""
  fi

  line
  printf '%sINSTALLATION SUMMARY%s\n' "$C_GREEN" "$C_RESET"
  printf '  Panel URL : https://%s\n' "$panel_domain"
  printf '  Admin user: %s\n' "$admin_user"
  printf '  Admin email: %s\n' "$admin_email"
  if [[ -n "$admin_pass" ]]; then
    printf '  Admin password: %s\n' "$admin_pass"
    warn "Save the password now. It is intentionally not written to the log."
  else
    warn "Admin password could not be verified. Check the log and create an admin account manually."
  fi
  printf '  Log file  : %s\n' "$LOG_FILE"
  line
  warn "DNS for $panel_domain must point to this VPS; ports 80 and 443 must be reachable."
  if [[ "$mode" == "both" ]]; then
    warn "Wings hostname is $wings_domain. Create DNS for it pointing to this VPS too."
    warn "Confirm the backend successfully created/configured the node before hosting servers."
  fi
}

main() {
  header
  check_os || { pause; exit 1; }
  while true; do
    header
    printf '%sSELECT AN OPTION%s\n\n' "$C_YELLOW" "$C_RESET"
    printf '  %s[1]%s Install Panel\n' "$C_WHITE" "$C_RESET"
    printf '  %s[2]%s Install Wings (requires an existing Panel node token)\n' "$C_WHITE" "$C_RESET"
    printf '  %s[3]%s Install Panel + Wings\n' "$C_WHITE" "$C_RESET"
    printf '  %s[4]%s Uninstaller Hub (safe removal not enabled yet)\n' "$C_WHITE" "$C_RESET"
    printf '  %s[0]%s Exit Installer\n' "$C_RED" "$C_RESET"
    line
    ask_choice
    case "$REPLY" in
      0) ok "Goodbye. Thanks for using LORDXSTAR Installer."; exit 0 ;;
      1)
        ask_domain
        run_panel_backend panel "$REPLY" || true
        pause
        ;;
      2)
        error "Wings-only installation needs a valid node configuration token from an existing Panel."
        warn "Without that token, Wings cannot securely join a Panel node."
        warn "Open Panel > Admin > Nodes > Configuration to obtain the node configuration."
        pause
        ;;
      3)
        ask_domain
        run_panel_backend both "$REPLY" || true
        pause
        ;;
      4)
        warn "Uninstaller is disabled in this build to prevent accidental deletion of server data."
        warn "Back up the Panel database, /var/www/pterodactyl, and Wings server data before removal."
        pause
        ;;
    esac
  done
}
main "$@"
