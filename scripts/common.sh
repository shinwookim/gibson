#!/usr/bin/env bash
# Shared helpers. Safe to source from scripts in this repository.
set -Eeuo pipefail

ROOT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
DRY_RUN="${DRY_RUN:-0}"
LOG_FILE="${LOG_FILE:-/var/log/debian-server-setup.log}"

timestamp() { date '+%Y-%m-%dT%H:%M:%S%z'; }
log() {
  local line="[$(timestamp)] $*"
  printf '%s\n' "$line"
  if [[ -w "$(dirname "$LOG_FILE")" ]] || [[ $EUID -eq 0 ]]; then
    printf '%s\n' "$line" >> "$LOG_FILE" 2>/dev/null || true
  fi
}
die() { log "ERROR: $*"; exit 1; }
on_error() {
  local rc=$?
  log "ERROR: command failed (exit=$rc, line=${BASH_LINENO[0]:-unknown}): ${BASH_COMMAND:-unknown}"
  exit "$rc"
}
trap on_error ERR

run() {
  if (( DRY_RUN )); then
    printf '[DRY-RUN]'
    printf ' %q' "$@"
    printf '\n'
  else
    "$@"
  fi
}
need_cmd() { command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"; }
require_root() { [[ $EUID -eq 0 ]] || die "Run with sudo/root."; }
require_debian() {
  local expected="${1:-13}" actual
  [[ -r /etc/os-release ]] || die "Cannot read /etc/os-release"
  # shellcheck disable=SC1091
  . /etc/os-release
  [[ "${ID:-}" == "debian" ]] || die "This setup supports Debian only (detected ${ID:-unknown})."
  if [[ "$expected" != "either" && -n "$expected" ]]; then
    [[ "${VERSION_ID%%.*}" == "$expected" ]] || die "Expected Debian $expected; detected ${VERSION_ID:-unknown}."
  fi
}
load_config() {
  local file="${1:-$ROOT_DIR/config/server.conf}"
  [[ -f "$file" ]] || die "Config not found: $file"
  # shellcheck disable=SC1090
  source "$file"
  : "${DEBIAN_VERSION:=13}" "${SSH_PORT:=22}" "${SSH_ALLOWED_SOURCES:=}"
  : "${TAILSCALE_INTERFACE:=tailscale0}" "${ENABLE_UNATTENDED_UPGRADES:=true}"
  : "${TIMEZONE:=UTC}" "${DATA_ROOT:=/srv}" "${DATA_DIRS:=appdata backups}"
  : "${ADMIN_USER:=}" "${ADMIN_SSH_PUBLIC_KEY:=}" "${ALLOW_DOCKER_REMOTE_API:=false}"
  [[ "$SSH_PORT" =~ ^[0-9]+$ ]] && (( SSH_PORT >= 1 && SSH_PORT <= 65535 )) || die "SSH_PORT must be 1-65535."
  [[ "$TAILSCALE_INTERFACE" =~ ^[a-zA-Z0-9_.-]+$ ]] || die "Invalid Tailscale interface name."
  [[ "$DATA_ROOT" == /* ]] || die "DATA_ROOT must be an absolute path."
}
parse_args() {
  while (($#)); do
    case "$1" in
      --dry-run) DRY_RUN=1; shift ;;
      --config) [[ $# -ge 2 ]] || die "--config requires a path"; CONFIG_FILE="$2"; shift 2 ;;
      -h|--help) echo "Options: --dry-run --config PATH"; exit 0 ;;
      *) die "Unknown argument: $1" ;;
    esac
  done
}
backup_file() {
  local file="$1"
  if [[ -e "$file" && $DRY_RUN -eq 0 ]]; then
    cp -a -- "$file" "${file}.bak.$(date +%Y%m%d%H%M%S)"
  fi
}
