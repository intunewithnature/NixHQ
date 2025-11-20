## NixHQ Infrastructure Overview

This repo is the system-definition source of truth for the Impious hosts. All configuration is expressed as a NixOS flake; application code, Caddyfile, and Docker compose files live separately under `/opt/impious` on each VPS.

---

### Hosts & Roles

- **Production VPS (`.#vps`)**
  - Host module: `hosts/vps.nix`
  - Hardware: `hardware-vps.nix`
  - Hostname: `impious-vps`
  - Compose file: `/opt/impious/deploy/docker-compose.yml`
  - Compose project name: `impious-prod`

- **Staging / Test VPS (`.#test-server`)**
  - Host module: `hosts/test-server.nix`
  - Hardware: `hardware-test-server.nix`
  - Hostname: `test-server`
  - Compose file: `/opt/impious/deploy/docker-compose.dev.yml`
  - Compose project name: `impious-staging`

Both hosts import the shared base stack located under `modules/common/`:

- `system.nix` – boot loader, swap file, timezone, journald persistence (1 GiB cap), base packages, flake features
- `security.nix` – nftables firewall (22/80/443 only), SSH lockdown, sudo rules, fail2ban defaults
- `docker.nix` – Docker engine enablement, weekly auto-prune, journald logging, `/opt/impious/deploy` directory management, and the Docker Compose v2 CLI plugin
- `caddy-stack.nix` – `impious-stack.service` systemd unit that drives the Docker/Caddy compose project, with tmpfiles guarding `/opt/impious/deploy/{site,codex}`
- `users/app-user.nix` – opinionated `app` deployment account (wheel + docker) with overridable SSH keys

The `services.impiousStack` unit wraps the compose deployment via `docker compose up -d --force-recreate`, runs as the `app` user, and exposes tunables for compose file names, environment files, and project identifiers. Systemd owns the lifecycle through `impious-stack.service`, ensuring `/opt/impious/deploy` and its static subdirectories stay owned by `app:docker`.

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
- Two static asset directories are managed by tmpfiles: `/opt/impious/deploy/site` (impious.io) and `/opt/impious/deploy/codex` (codex.imperiumsolis.com). The application repo must mount them into the Caddy container as `/srv/site` and `/srv/codex`, respectively, and supply the accompanying Caddyfile blocks.
- The `impious-stack` systemd unit runs `docker compose up -d --force-recreate --remove-orphans`, restarts on failures, and tears everything down via `docker compose down` when stopped.
- The module will recreate `/opt/impious/deploy` with `app:docker` ownership if it disappears, but operators are responsible for providing the compose files, built static assets, and secret `.env` files.

---

### CI Guarantees

- `.github/workflows/flake-check.yml` installs Nix, runs `nix flake check --print-build-logs`, and builds both host system closures (`nix build .#nixosConfigurations.test-server.config.system.build.toplevel` and `.#nixosConfigurations.vps.config.system.build.toplevel`) on pushes/PRs targeting `main`/`master`
- `.github/workflows/cursor-code-review.yml` is enabled for PR reviews (move secrets into the repo settings before relying on it)
- Use this to validate configuration changes before deploying

---

### Operator Cheat Sheet

- **Deploy new configuration**
  - Staging first: `sudo nixos-rebuild switch --flake /etc/nixos#test-server`
  - Production next: `sudo nixos-rebuild switch --flake /etc/nixos#vps`

- **Investigate services**
  - Caddy/Docker stack: `systemctl status impious-stack` (defined in `modules/common/caddy-stack.nix`)
  - Firewall rules: inspect `modules/common/security.nix` and confirm with `sudo nft list ruleset`
  - SSH access: `modules/common/security.nix`; override `deploy.appUser.authorizedKeys` per-host

Keep this document in sync when adding new hosts, services, or security controls.
