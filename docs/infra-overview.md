## NixHQ Infrastructure Overview

This repo is the system-definition source of truth for the Impious hosts. All configuration is expressed as a NixOS flake; application code and Docker compose files live separately under `/opt/impious` on each VPS.

---

### Hosts & Roles

- **Production VPS**
  - Flake output: `.#vps`
  - Host module: `hosts/vps.nix`
  - Hardware file: `hardware-vps.nix`
  - Hostname: `impious-vps`
  - Expected app directory: `/opt/impious/deploy`

- **Staging / Test VPS**
  - Flake output: `.#test-server`
  - Host module: `hosts/test-server.nix`
  - Hardware file: `hardware-test-server.nix`
  - Hostname: `test-server`
  - Expected app directory: `/opt/impious/deploy`

Both hosts import the shared base stack located under `modules/`:

- `base-system.nix` – boot loader, swap, timezone, journald persistence, base packages, and flake features
- `security.nix` – firewall, SSH hardening, sudo policy, and fail2ban defaults
- `docker-host.nix` – Docker engine tuning, auto-prune, and base `/opt/impious` directory management
- `users/app-user.nix` – opinionated `app` deployment account (wheel + docker) with overridable SSH keys
- `modules/caddy-stack.nix` – systemd-managed Compose stack for Caddy and supporting containers

The `services.caddyStack` unit now keeps the compose project in the foreground (systemd `Type=simple`), runs as the non-root `app` user with the `docker` primary group, and will automatically recreate `/opt/impious/deploy` with 0750 permissions if it goes missing. Restarts happen automatically when the compose process exits with an error, and you can feed additional environment files via `services.caddyStack.environmentFiles`.

---

### Security Invariants

- **Firewall**
  - Enabled via `networking.firewall`
  - Only TCP ports `22`, `80`, and `443` are exposed externally
  - Refused connections are logged for audit trails

- **SSH**
  - `services.openssh.enable = true`
  - `PermitRootLogin = "no"`
  - `PasswordAuthentication = false`
  - `KbdInteractiveAuthentication = false`
  - `AllowUsers app` restricts SSH access to the `app` account
  - Agent forwarding, TCP forwarding, and X11 forwarding are disabled
  - Idle connections are trimmed via `ClientAliveInterval = 300`, `ClientAliveCountMax = 2`, and `LoginGraceTime = 30s`
  - All access assumes valid SSH keys are already deployed

- **Fail2ban**
  - `services.fail2ban.enable = true`
  - Configured to use the `systemd` backend and the default `sshd` jail with a 5-attempt / 15-minute ban policy

Adjustments to these controls must be reviewed carefully—loosening them affects both environments.

---

### User & Privilege Invariants

- **`app` user**
  - Defined in `modules/users/app-user.nix`
  - Home: `/home/app`, shell: `bashInteractive`
  - Member of `wheel` and `docker`
  - SSH keys controlled through `deploy.appUser.authorizedKeys` so staging/production can diverge without editing the module itself

- **Privilege model**
  - `wheel` membership plus `security.sudo.wheelNeedsPassword = true` → sudo requires the user’s password
  - Membership in `docker` is root-equivalent per Docker’s security model; operators must treat the `app` account as highly privileged

---

### Deployment Expectations

- Application stack lives under `/opt/impious`
- Docker Compose project (including the Caddy reverse proxy) is located at `/opt/impious/deploy`
- The `caddy-stack` systemd unit runs `docker-compose up --remove-orphans` in the foreground, so systemd can restart it automatically if any container chain exits unexpectedly
- The module will recreate `/opt/impious/deploy` with `app:docker` ownership if it disappears, but operators are responsible for providing the compose files and secret `.env` files

---

### CI Guarantees

- `.github/workflows/flake-check.yml` runs `nix flake check` on pushes and pull requests to `main`/`master`
- `.github/workflows/cursor-code-review.yml` is enabled for PR reviews (move secrets into the repo settings before relying on it)
- Use this to validate configuration changes before deploying

---

### Operator Cheat Sheet

- **Deploy new configuration**
  - Production: `sudo nixos-rebuild switch --flake /etc/nixos#vps`
  - Staging: `sudo nixos-rebuild switch --flake /etc/nixos#test-server`

- **Investigate services**
  - Caddy/Docker stack: `systemctl status caddy-stack` (defined in `modules/caddy-stack.nix`)
  - Firewall rules: inspect `modules/security.nix` and confirm with `sudo nft list ruleset`
  - SSH access: `modules/security.nix`; override `deploy.appUser.authorizedKeys` per-host

Keep this document in sync when adding new hosts, services, or security controls.
