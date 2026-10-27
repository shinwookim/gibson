#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root
log "Verification report"
printf '\n== OS ==\n'; cat /etc/os-release
printf '\n== Failed systemd units ==\n'
if (( DRY_RUN )); then log "Would run systemctl --failed --no-pager"; else systemctl --failed --no-pager || true; fi
printf '\n== Listening TCP/UDP sockets ==\n'
if (( DRY_RUN )); then log "Would run ss -lntup"; else ss -lntup || true; fi
printf '\n== SSH ==\n'
if (( DRY_RUN )); then log "Would check ssh service"; else systemctl is-active ssh || true; sshd -t; fi
printf '\n== nftables ==\n'
if (( DRY_RUN )); then log "Would run nft list ruleset"; else nft list ruleset || true; fi
printf '\n== Docker (if installed) ==\n'
if command -v docker >/dev/null 2>&1; then if (( DRY_RUN )); then log "Docker detected"; else docker info >/dev/null && docker --version; fi; else echo "Not installed"; fi
printf '\n== Tailscale (if installed) ==\n'
if command -v tailscale >/dev/null 2>&1; then if (( DRY_RUN )); then log "Tailscale detected"; else tailscale status || true; fi; else echo "Not installed"; fi
printf '\n== Nginx (if installed) ==\n'
if command -v nginx >/dev/null 2>&1; then if (( DRY_RUN )); then log "Would run nginx -t"; else nginx -t; systemctl is-active nginx || true; fi; else echo "Not installed"; fi
printf '\n== Disk usage ==\n'
if (( DRY_RUN )); then log "Would run df -h"; else df -h; fi
log "Verification checks complete."
