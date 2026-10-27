#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"
export DEBIAN_FRONTEND=noninteractive
run apt-get update
run apt-get install -y --no-install-recommends ca-certificates curl wget git vim-tiny tmux htop jq sudo gnupg lsb-release nftables openssh-server
if command -v timedatectl >/dev/null 2>&1; then
  run timedatectl set-timezone "$TIMEZONE"
  run timedatectl set-ntp true
fi
log "System baseline packages/time configuration complete."
