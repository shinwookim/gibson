# Debian 13 Homelab Setup

A modular, Bash-based starter repository for provisioning a **Debian 13 (Trixie)** homelab. It installs baseline tools, configures an admin account and SSH conservatively, enables security updates, sets up a native `nftables` firewall, and provides optional Docker, Tailscale, Nginx, data-directory, and verification modules.

> **Safety:** This repository has been generated but has not been run against a server. Review every script and configuration before use. Run `./bootstrap.sh --dry-run` first. Dry-run is an intent preview, not a sandbox and not a guarantee that every external command has been simulated.

## Design principles

- **Modular:** baseline steps are separate scripts; optional components can be run independently.
- **Rerunnable:** scripts check current state and avoid appending duplicate config.
- **Fail visibly:** strict Bash mode, shared logging, and explicit validation.
- **Conservative:** no disk formatting, no automatic reboot, no existing user deletion, and no SSH password-authentication changes.
- **Tailscale-first:** the firewall permits SSH on the Tailscale interface by default and does not expose SSH on the LAN/WAN unless configured.
- **No secrets in Git:** Tailscale authentication is interactive by default.

## Requirements

- A fresh or otherwise understood Debian 13 installation.
- Console / out-of-band recovery access, especially when changing firewall or SSH configuration.
- A sudo-capable user or root access.
- Internet connectivity for package repositories and upstream installers.
- Bash 5+, `systemd`, and `apt`.

## Quick start

```bash
git clone <your-repository-url> debian-server-setup
cd debian-server-setup

# Review configuration first.
vim config/server.conf

# Preview planned operations.
sudo ./bootstrap.sh --dry-run

# Apply baseline setup.
# IMPORTANT: before the baseline reaches the firewall module, either:
# (A) set SSH_ALLOWED_SOURCES to your trusted LAN CIDR in config/server.conf, OR
# (B) install and authenticate Tailscale first, then run the baseline.
sudo ./scripts/08-tailscale.sh
sudo tailscale up
sudo ./bootstrap.sh

# Optional modules (also safe to rerun).
sudo ./scripts/07-docker.sh
sudo ./scripts/09-nginx.sh
sudo ./scripts/06-storage.sh
sudo ./scripts/99-verify.sh
```

`bootstrap.sh` runs modules `01-system`, `02-user`, `03-ssh`, `04-firewall`, and `05-security` in that order. Because the firewall step intentionally fails closed if there is no Tailscale interface and no explicit SSH source, prepare Tailscale or configure a trusted SSH source before running the baseline. Optional services are intentionally not installed automatically by the baseline. Run them when ready.

## Configuration

Edit `config/server.conf`. Values are loaded as Bash assignments, so **only source a configuration file you trust**.

Important settings:

- `ADMIN_USER`: optional admin account to create/add to sudo. Empty means don't create a user.
- `ADMIN_SSH_PUBLIC_KEY`: optional public key literal. Prefer placing the public key in the user's `~/.ssh/authorized_keys` yourself, or use a carefully reviewed secret-management workflow.
- `SSH_PORT`: SSH port used by the firewall.
- `SSH_ALLOWED_SOURCES`: nftables source CIDRs allowed to SSH. Empty means no direct-IP SSH allowance; Tailscale-interface SSH is allowed when enabled.
- `TAILSCALE_INTERFACE`: normally `tailscale0`.
- `DATA_ROOT`: directory for homelab data, default `/srv`.
- `DATA_DIRS`: whitespace-separated directory names created below `DATA_ROOT`.
- `ENABLE_UNATTENDED_UPGRADES`: install/configure unattended security updates.
- `ALLOW_DOCKER_REMOTE_API`: should remain `false`; the script does not expose a remote Docker API.

## Firewall behavior and lockout prevention

The nftables module creates `/etc/nftables.conf` from the repository template and enables `nftables.service`. As a lockout safeguard, it refuses to apply if neither the configured Tailscale interface exists nor `SSH_ALLOWED_SOURCES` is set. Its default policy is drop for inbound traffic, accepts established/related traffic and loopback, allows ICMP/ICMPv6, and allows SSH only on `tailscale0` plus explicitly configured source CIDRs.

**Before applying:** verify the interface name, SSH port, and source ranges. A firewall can lock you out. Use console access and keep an existing session open. The module validates syntax with `nft -c -f` before applying. It backs up the previous `/etc/nftables.conf` when present, but cannot guarantee recovery from every remote/network failure.

To permit SSH from a trusted LAN, set e.g. `SSH_ALLOWED_SOURCES="192.168.1.0/24"` and rerun the firewall module. Avoid broad public CIDRs.

Docker manages its own packet-filtering rules and can publish container ports in ways that bypass assumptions made from a host firewall alone. Publish only required ports, and bind services to intended addresses. Review Docker's firewall documentation before relying on nftables as the only boundary.

## SSH behavior

The SSH module validates the daemon configuration with `sshd -t` before reloading. It does **not** disable password authentication or root login automatically. Harden those settings only after confirming key-based access in a second session and keeping console recovery available.

## Docker

Installs Docker Engine and the Compose plugin from Debian's packaged `docker.io` and `docker-compose` packages, avoiding an extra vendor repository by default. Package versions may lag upstream. The module does not add users to the `docker` group automatically: membership in that group is effectively root access.

## Tailscale

Installs Tailscale using Tailscale's official convenience installer if the package is not already installed, then enables `tailscaled`. It does not embed or persist an auth key. Run `sudo tailscale up` interactively to authenticate and review the requested network settings.

## Nginx

Installs Debian's `nginx` package and enables the service. It does not create a default reverse-proxy virtual host or open HTTP/HTTPS in nftables automatically. Add only the ports you actually need and configure TLS deliberately.

## Storage

`06-storage.sh` only creates directories under `DATA_ROOT` and sets conservative ownership/modes. It does **not** partition, format, mount, or edit `/etc/fstab`. Review `DATA_DIRS` and `DATA_ROOT` before running.

## Dry-run limits

`--dry-run` logs intended commands through shared wrappers. It cannot fully predict package-manager scripts, service side effects, installer behavior, or all shell built-ins. Some validation/read-only commands may still execute. Treat it as a review aid, not as a substitute for a disposable test VM.

## File map

```text
bootstrap.sh
config/server.conf
profiles/minimal.conf
profiles/docker-host.conf
profiles/homelab.conf
scripts/common.sh
scripts/01-system.sh
scripts/02-user.sh
scripts/03-ssh.sh
scripts/04-firewall.sh
scripts/05-security.sh
scripts/06-storage.sh
scripts/07-docker.sh
scripts/08-tailscale.sh
scripts/09-nginx.sh
scripts/99-verify.sh
```

## Suggested test plan

1. Test in a disposable Debian 13 VM with a snapshot.
2. Run `bash -n` against every script.
3. Run `./bootstrap.sh --dry-run` and review all output.
4. Apply baseline from the VM console.
5. Verify SSH from a second session before ending the original session.
6. Check `sudo nft list ruleset`, `systemctl --failed`, and `ss -lntup`.
7. Install optional modules one at a time and verify their service state.
8. Test a second run to confirm idempotency.

## License

Choose and add a license before publishing this repository.
