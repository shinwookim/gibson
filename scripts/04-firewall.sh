#!/usr/bin/env bash
set -Eeuo pipefail
source "$(dirname -- "${BASH_SOURCE[0]}")/common.sh"
CONFIG_FILE="$ROOT_DIR/config/server.conf"; while (($#)); do case "$1" in --dry-run) DRY_RUN=1; shift;; --config) CONFIG_FILE="$2"; shift 2;; *) die "Unknown argument: $1";; esac; done
load_config "$CONFIG_FILE"; require_root; require_debian "$DEBIAN_VERSION"
need_cmd nft
# Prevent the most common remote lockout: no Tailscale interface yet and no explicit SSH source.
if [[ -z "$SSH_ALLOWED_SOURCES" ]] && ! ip link show "$TAILSCALE_INTERFACE" >/dev/null 2>&1; then
  die "No $TAILSCALE_INTERFACE interface and SSH_ALLOWED_SOURCES is empty. Authenticate Tailscale first, or configure a trusted SSH source CIDR before enabling the firewall."
fi
# Construct an nftables ruleset from validated config values. SSH sources are CIDRs.
tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
{
  cat <<'RULES'
#!/usr/sbin/nft -f
flush ruleset
table inet filter {
  chain input {
    type filter hook input priority filter; policy drop;
    iifname "lo" accept
    ct state established,related accept
    ct state invalid drop
    ip protocol icmp accept
    ip6 nexthdr icmpv6 accept
RULES
  printf '    iifname "%s" tcp dport %s accept\n' "$TAILSCALE_INTERFACE" "$SSH_PORT"
  for cidr in $SSH_ALLOWED_SOURCES; do
    [[ "$cidr" =~ ^[0-9a-fA-F:.\/]+$ ]] || die "Invalid-looking SSH source CIDR: $cidr"
    if [[ "$cidr" == *:* ]]; then
      printf '    ip6 saddr %s tcp dport %s accept\n' "$cidr" "$SSH_PORT"
    else
      printf '    ip saddr %s tcp dport %s accept\n' "$cidr" "$SSH_PORT"
    fi
  done
  cat <<'RULES'
    # Permit outbound traffic and its replies; input policy remains drop.
  }
  chain forward {
    type filter hook forward priority filter; policy drop;
  }
  chain output {
    type filter hook output priority filter; policy accept;
  }
}
RULES
} > "$tmp"

if (( DRY_RUN )); then
  log "Would install nftables ruleset (preview follows):"
  cat "$tmp"
  log "Would validate with nft -c -f, back up /etc/nftables.conf, install, and enable nftables."
  exit 0
fi
nft -c -f "$tmp"
backup_file /etc/nftables.conf
install -m 600 "$tmp" /etc/nftables.conf
# Validate installed file too before enabling/applying.
nft -c -f /etc/nftables.conf
systemctl enable nftables
systemctl restart nftables
log "nftables enabled. Verify remote access immediately from a second session."
