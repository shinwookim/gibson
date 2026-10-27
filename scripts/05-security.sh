#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"
if [[ "$ENABLE_UNATTENDED_UPGRADES" == "true" ]]; then
  run apt-get install -y unattended-upgrades
  if (( DRY_RUN )); then
    log "Would enable unattended-upgrades service if available."
  else
    dpkg-reconfigure -f noninteractive unattended-upgrades
    systemctl enable --now unattended-upgrades.service 2>/dev/null || true
  fi
else
  log "Unattended upgrades disabled by configuration."
fi
run systemctl enable --now systemd-timesyncd 2>/dev/null || true
log "Security update configuration complete."
