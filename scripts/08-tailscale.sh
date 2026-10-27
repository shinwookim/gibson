#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"
if command -v tailscale >/dev/null 2>&1; then
  log "Tailscale CLI already installed."
else
  if (( DRY_RUN )); then
    log "Would download and run the official Tailscale installer. Review https://tailscale.com/download/linux before applying."
  else
    if ! command -v curl >/dev/null 2>&1; then
      export DEBIAN_FRONTEND=noninteractive
      run apt-get update
      run apt-get install -y ca-certificates curl
    fi
    if (( DRY_RUN )); then
      log "Dry-run: curl may not be present yet; installer download will not be attempted."
      exit 0
    fi
    curl -fsSL https://tailscale.com/install.sh -o /tmp/tailscale-install.sh
    bash /tmp/tailscale-install.sh
    rm -f /tmp/tailscale-install.sh
  fi
fi
run systemctl enable --now tailscaled
if (( DRY_RUN )); then
  log "Would show tailscale status and instruct you to run 'tailscale up' interactively."
else
  tailscale status || true
  log "Authenticate interactively with: sudo tailscale up"
fi
