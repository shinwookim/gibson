#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"
export DEBIAN_FRONTEND=noninteractive
run apt-get update
run apt-get install -y nginx
if (( DRY_RUN )); then log "Would validate Nginx configuration and enable/start service."; else nginx -t; run systemctl enable --now nginx; fi
log "Nginx installed. No virtual hosts or firewall ports were added."
