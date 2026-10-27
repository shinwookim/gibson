#!/usr/bin/env bash
set -Eeuo pipefail
ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
source "$ROOT_DIR/scripts/common.sh"

usage() {
  cat <<'USAGE'
Usage: sudo ./bootstrap.sh [--dry-run] [--config PATH]

Runs the baseline modules in order:
  01-system, 02-user, 03-ssh, 04-firewall, 05-security
Optional modules are run separately.
USAGE
}

CONFIG_FILE="$ROOT_DIR/config/server.conf"
while (($#)); do
  case "$1" in
    --dry-run) DRY_RUN=1; shift ;;
    --config) [[ $# -ge 2 ]] || die "--config requires a path"; CONFIG_FILE="$2"; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) die "Unknown argument: $1" ;;
  esac
done

load_config "$CONFIG_FILE"
require_root
require_debian "$DEBIAN_VERSION"
log "Starting Debian server baseline (dry-run=$DRY_RUN)"
for script in 01-system.sh 02-user.sh 03-ssh.sh 04-firewall.sh 05-security.sh; do
  log "Running $script"
  if (( DRY_RUN )); then
    bash "$ROOT_DIR/scripts/$script" --dry-run --config "$CONFIG_FILE"
  else
    bash "$ROOT_DIR/scripts/$script" --config "$CONFIG_FILE"
  fi
done
log "Baseline complete. Run optional modules when ready."
