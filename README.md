# LORDXSTAR Pterodactyl Installer

A clean, menu-driven Bash installer UI for Pterodactyl Panel and Wings.

**Made by LORDXSTAR**

## Features

- Colourful terminal UI with `[+]`, `[✓]`, and `[✗]` status indicators.
- Strict menu validation: invalid inputs such as `6`, `7`, `all`, or `abc` show **Galat Option!** and return to the menu.
- Progress indicators instead of flooding the terminal with package-manager output.
- Restricted logs under `/var/log/lordxstar-installer`.
- Domain validation and generated database credentials, timezone, admin email, and Wings hostname defaults.
- Uses a third-party installer backend for actual deployment.

## Supported operating systems

- Ubuntu 22.04 LTS
- Ubuntu 24.04 LTS

Use a fresh VPS as root. The Panel domain must resolve to the VPS and inbound ports 80/443 must be reachable for TLS. For combined Panel + Wings, the generated `node.<base-domain>` hostname must also resolve to the VPS. The script stops before installation if the required DNS name(s) do not resolve.

## Run

```bash
git clone https://github.com/lordxstar1/Panel-Install-Pterodactyl.git
cd Panel-Install-Pterodactyl
chmod +x install.sh
sudo ./install.sh
```

## Menu

- `1` — Install Panel. Enter the Panel domain; the script chooses an admin email and generates database credentials.
- `2` — Wings-only guidance. Wings needs a valid node configuration token from an existing Panel, so this option does not pretend to install a usable node without one.
- `3` — Install Panel + Wings. Uses `node.<base-domain>` as the Wings hostname.
- `4` — Uninstaller information. Destructive uninstallation is intentionally disabled.
- `0` — Exit.

## Logs and credentials

- Logs: `/var/log/lordxstar-installer/install-YYYYMMDD-HHMMSS.log`
- Save the generated administrator credentials displayed at the end.
- Verify Panel, database, web server, and Wings status before hosting workloads.

## Backend note

This project uses the non-interactive interface of the [2hoch1/pterodactyl-installer](https://github.com/2hoch1/pterodactyl-installer) backend. It is a third-party community project, not the official Pterodactyl project. Review its source and test on a disposable VPS before running any installer as root. Backend updates can change behaviour.

## Safety

Installation changes packages, services, web-server configuration, and databases. Use a fresh VPS and back up important data before reinstalling. The uninstaller is disabled to avoid accidental data loss.
