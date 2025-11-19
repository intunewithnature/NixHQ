## NixHQ Infrastructure Overview

This repo is the system-definition source of truth for the Impious hosts. All configuration is expressed as a NixOS flake; application code and Docker compose files live separately under `/opt/impious` on each VPS.

---

### Hosts & Roles

- **Production VPS**
  - Flake output: `.#vps`
  - Host module: `hosts/vps.nix`
  - Base module: `configuration.nix`
  - Hardware file: `hardware-vps.nix`
  - Hostname: `impious-vps`
  - Expected app directory: `/opt/impious/deploy`

- **Staging / Test VPS**
  - Flake output: `.#test-server`
  - Host module: `hosts/test-server.nix`
  - Base module: `configuration.nix`
  - Hardware file: `hardware-test-server.nix`
  - Hostname: `test-server`
  - Expected app directory: `/opt/impious/deploy`

Both hosts import the shared `modules/caddy-stack.nix` module and enable the `services.caddyStack` systemd unit. The unit simply runs `docker-compose up/down` inside `/opt/impious/deploy` as soon as Docker and networking are ready.

---

### Security Invariants

- **Firewall**
  - Enabled via `networking.firewall`
  - Only TCP ports `22`, `80`, and `443` are exposed externally

- **SSH**
  - `services.openssh.enable = true`
  - `PermitRootLogin = "no"`
  - `PasswordAuthentication = false`
  - `KbdInteractiveAuthentication = false`
  - `AllowUsers app` restricts SSH access to the `app` account
  - All access assumes valid SSH keys are already deployed

- **Fail2ban**
  - `services.fail2ban.enable = true`
  - Configured to use the `systemd` backend and the default `sshd` jail with a 5-attempt / 15-minute ban policy

Adjustments to these controls must be reviewed carefully—loosening them affects both environments.

---

### User & Privilege Invariants

- **`app` user**
  - Defined in `configuration.nix`
  - Home: `/home/app`, shell: `bashInteractive`
  - Member of `wheel` and `docker`
  - SSH key hard-coded in config; rotate as needed

- **Privilege model**
  - `wheel` membership plus `security.sudo.wheelNeedsPassword = true` → sudo requires the user’s password
  - Membership in `docker` is root-equivalent per Docker’s security model; operators must treat the `app` account as highly privileged
  - The config contains comments near the user definition reminding operators of these implications

---

### Deployment Expectations

- Application stack lives under `/opt/impious`
- Docker Compose project (including the Caddy reverse proxy) is located at `/opt/impious/deploy`
- The `caddy-stack` systemd unit runs `docker-compose up -d` / `down` inside that directory
- Operators should ensure the directory exists and contains the expected compose files before enabling the service

---

### CI Guarantees

- `.github/workflows/flake-check.yml` runs `nix flake check` on pushes and pull requests to `main`/`master`
- Use this to validate configuration changes before deploying

---

### Operator Cheat Sheet

- **Deploy new configuration**
  - Production: `sudo nixos-rebuild switch --flake /etc/nixos#vps`
  - Staging: `sudo nixos-rebuild switch --flake /etc/nixos#test-server`

- **Investigate services**
  - Caddy/Docker stack: `systemctl status caddy-stack` (defined in `modules/caddy-stack.nix`)
  - Firewall rules: inspect `networking.firewall` in `configuration.nix` and confirm with `sudo nft list ruleset`
  - SSH access: `services.openssh` settings live in `configuration.nix`

Keep this document in sync when adding new hosts, services, or security controls.
