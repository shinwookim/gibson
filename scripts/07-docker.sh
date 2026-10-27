#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"
if [[ "$ALLOW_DOCKER_REMOTE_API" != "false" ]]; then die "Remote Docker API configuration is not supported by this script."; fi
export DEBIAN_FRONTEND=noninteractive
run apt-get update
run apt-get install -y docker.io docker-compose
run systemctl enable --now docker
if (( DRY_RUN )); then log "Would verify Docker daemon and Compose availability."; else docker --version; docker compose version 2>/dev/null || docker-compose --version; fi
log "Docker installed. No user was added to the docker group."
