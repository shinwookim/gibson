#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"
case "$DATA_ROOT" in /|/etc|/usr|/var|/home|/root) die "Refusing unsafe DATA_ROOT: $DATA_ROOT";; esac
for name in $DATA_DIRS; do
  [[ "$name" =~ ^[a-zA-Z0-9][a-zA-Z0-9_.-]*$ ]] || die "Invalid data directory name: $name"
  path="${DATA_ROOT%/}/$name"
  if (( DRY_RUN )); then log "Would create directory $path (root:root, mode 0750)."
  else install -d -o root -g root -m 0750 -- "$path"; fi
done
log "Data directories ready under $DATA_ROOT. No disks were mounted or modified."
