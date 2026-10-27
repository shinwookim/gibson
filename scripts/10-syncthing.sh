#!/usr/bin/env bash
set -Eeuo pipefail

# Install and configure Syncthing as a systemd service for a regular user.
#
# Required config:
#   SYNCTHING_USER="your-user"
#
# Optional config:
#   DRY_RUN=false
#
# Usage:
#   sudo ./scripts/10-syncthing.sh

source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

if [[ -f "${SCRIPT_DIR}/common.sh" ]]; then
    # shellcheck source=common.sh
    source "${SCRIPT_DIR}/common.sh"
fi

log() {
    if declare -F info >/dev/null 2>&1; then
        info "$@"
    else
        printf '[INFO] %s\n' "$*"
    fi
}

warn() {
    if declare -F warning >/dev/null 2>&1; then
        warning "$@"
    else
        printf '[WARN] %s\n' "$*" >&2
    fi
}

die() {
    if declare -F error >/dev/null 2>&1; then
        error "$@"
    else
        printf '[ERROR] %s\n' "$*" >&2
    fi
    exit 1
}

DRY_RUN="${DRY_RUN:-false}"
SYNCTHING_USER="${SYNCTHING_USER:-}"

run() {
    if [[ "$DRY_RUN" == "true" ]]; then
        printf '[DRY-RUN]'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

# Require root for package installation and system service management.
if [[ "${EUID}" -ne 0 ]]; then
    die "Run this script with sudo or as root."
fi

if [[ -z "$SYNCTHING_USER" ]]; then
    die "Set SYNCTHING_USER to the regular Linux account that should run Syncthing."
fi

if ! id "$SYNCTHING_USER" >/dev/null 2>&1; then
    die "User '$SYNCTHING_USER' does not exist."
fi

if [[ "$SYNCTHING_USER" == "root" ]]; then
    die "Syncthing must run as a regular, non-root user."
fi

if ! command -v systemctl >/dev/null 2>&1; then
    die "systemd is required for this script."
fi

if [[ "$DRY_RUN" != "true" ]] && ! systemctl is-system-running >/dev/null 2>&1; then
    warn "systemd may not be fully operational; service operations might fail."
fi

install_syncthing() {
    if command -v syncthing >/dev/null 2>&1; then
        log "Syncthing is already installed."
        return
    fi

    if command -v apt-get >/dev/null 2>&1; then
        log "Installing Syncthing using apt."
        run apt-get update
        run apt-get install -y syncthing
    elif command -v dnf >/dev/null 2>&1; then
        log "Installing Syncthing using dnf."
        run dnf install -y syncthing
    elif command -v pacman >/dev/null 2>&1; then
        log "Installing Syncthing using pacman."
        run pacman -Sy --needed --noconfirm syncthing
    elif command -v zypper >/dev/null 2>&1; then
        log "Installing Syncthing using zypper."
        run zypper --non-interactive install syncthing
    else
        die "No supported package manager found. Install Syncthing manually first."
    fi
}

configure_service() {
    local unit="syncthing@${SYNCTHING_USER}.service"

    if ! systemctl cat "$unit" >/dev/null 2>&1; then
        die "Systemd unit '$unit' is unavailable. Check the Syncthing package for your distribution."
    fi

    log "Enabling and starting ${unit}."
    run systemctl enable --now "$unit"

    if [[ "$DRY_RUN" != "true" ]]; then
        if ! systemctl is-active --quiet "$unit"; then
            die "Syncthing did not become active. Inspect: journalctl -u ${unit}"
        fi
        log "Syncthing is running for user '${SYNCTHING_USER}'."
    fi
}

main() {
    install_syncthing
    configure_service

    cat <<EOF

Syncthing setup complete.

Service:
  syncthing@${SYNCTHING_USER}.service

Status:
  systemctl status syncthing@${SYNCTHING_USER}.service

Logs:
  journalctl -u syncthing@${SYNCTHING_USER}.service -f

GUI:
  By default, access it locally on the server at http://127.0.0.1:8384.
  To access it remotely, create an SSH tunnel from your client:
    ssh -L 8385:127.0.0.1:8384 ${SYNCTHING_USER}@YOUR_SERVER
  Then open http://127.0.0.1:8385 on your client.

Note:
  Ensure '${SYNCTHING_USER}' has permission to read/write the folders
  you intend to sync. This script does not change /srv permissions
  or configure firewall rules.
EOF
}

main "$@"
