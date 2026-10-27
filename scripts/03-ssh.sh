#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"
need_cmd sshd
# Conservative change: ensure SSH is enabled; do not rewrite authentication policy.
run systemctl enable ssh
if (( DRY_RUN )); then
  log "Would validate sshd configuration with sshd -t and reload SSH if valid."
else
  sshd -t
  if systemctl is-active --quiet ssh; then run systemctl reload ssh; else run systemctl start ssh; fi
fi
log "SSH service enabled and configuration validated. Authentication policy unchanged."
