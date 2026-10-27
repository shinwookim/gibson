#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"
if [[ -z "$ADMIN_USER" ]]; then log "ADMIN_USER is empty; skipping account changes."; exit 0; fi
[[ "$ADMIN_USER" =~ ^[a-z_][a-z0-9_-]*[$]?$ ]] || die "ADMIN_USER has an invalid username format."
if ! id "$ADMIN_USER" >/dev/null 2>&1; then run useradd --create-home --shell /bin/bash "$ADMIN_USER"; fi
run usermod -aG sudo "$ADMIN_USER"
if [[ -n "$ADMIN_SSH_PUBLIC_KEY" ]]; then
  home_dir="$(getent passwd "$ADMIN_USER" | cut -d: -f6)"
  [[ -n "$home_dir" && "$home_dir" == /* ]] || die "Could not resolve user's home directory."
  ssh_dir="$home_dir/.ssh"
  if (( DRY_RUN )); then
    log "Would create $ssh_dir and append configured public key if missing."
  else
    install -d -m 700 -o "$ADMIN_USER" -g "$ADMIN_USER" "$ssh_dir"
    auth="$ssh_dir/authorized_keys"
    touch "$auth"; chown "$ADMIN_USER:$ADMIN_USER" "$auth"; chmod 600 "$auth"
    grep -Fqx -- "$ADMIN_SSH_PUBLIC_KEY" "$auth" || printf '%s\n' "$ADMIN_SSH_PUBLIC_KEY" >> "$auth"
  fi
fi
log "Admin user setup complete for $ADMIN_USER."
