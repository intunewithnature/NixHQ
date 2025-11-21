## Infra Reality — Hardened Stack

### Hosts at a glance
- `.#vps` → `hosts/vps.nix` (production): `docker-compose.yml`, TLS enabled, domain `impious.io`, fail2ban identifier `impious-prod-caddy`.
- `.#test-server` → `hosts/test-server.nix` (staging): `docker-compose.dev.yml`, TLS disabled, fake domain `staging.impious.invalid`, extra env `CADDY_STAGING_NOTE`, fail2ban identifier `impious-staging-caddy`.
- Both share hardware profiles (`hardware-*.nix`) and the base module list from `configuration.nix`.

### Typed impious stack module
`modules/common/impious-stack.nix` defines `services.impiousStack` with:
- Path-typed `deployDir` (`/opt/impious/deploy`) and tmpfiles to guard static dirs.
- User/group toggles (defaults `app:docker`) and capability sandboxing (`CAP_NET_BIND_SERVICE`, `NoNewPrivileges`, `RestrictAddressFamilies`).
- Host overrides for `composeFile`, `projectName`, `tlsMode`, `primaryDomain`, `extraEnvironment`, and journald `fail2banIdentifier`.
- Secrets contract: `secretEnvFile`, optional `secretSopsFile`, `manageSecretFile`, `extraEnvFiles`.
- Systemd oneshot unit that waits for Docker/network, runs `docker compose up -d --force-recreate --remove-orphans`, keeps env vars in sync, and tears down via `docker compose down`.

### Docker substrate
`modules/common/docker.nix`:
- Enables Docker + weekly `docker system prune --all --volumes`.
- Forces journald logging with bounded buffers (`mode=non-blocking`, `max-buffer-size=8m`, tag=`{{.Name}}`) and `live-restore` to survive daemon restarts.
- Creates `/opt/impious` roots owned by `app:docker` and installs compose CLI plugin system-wide.

### Security posture
- Firewall: nftables, allow TCP 22/80/443 only, log refused packets.
- SSH: `PermitRootLogin no`, key-only auth, forwarding disabled, `AllowUsers app`, aggressive timeouts.
- Fail2ban:
  - Default sshd jail (5 strikes / 15 minutes).
  - `caddy-http` jail (journald backend) keyed off `services.impiousStack.fail2banIdentifier`, banning abusive HTTP clients on ports 80/443.
- `app` user:
  ```nix
  users.users.app = {
    group = "app";
    extraGroups = [ "wheel" "docker" ];
  };
  users.groups.app = {};
  ```
  Ensures secret files (`0600`) stay readable by the service owner only.

### Secrets + docs
- `.env.example` and `docs/secrets.md` describe every key and the SOPS workflow.
- `sops-nix` is imported globally; set `services.impiousStack.secretSopsFile = ./secrets/<env>.env` per host to decrypt automatically.
- `docs/deploy-playbook.md` gives the staging-first apply path; `docs/reality-check.md` keeps the historical baseline snapshot.

### CI / CD
- `Flake CI` workflow: runs on `main`, `master`, and `dev`. Installs a pinned Nix, prints metadata, runs `nix flake check`, and builds both host closures.
- `Deploy (stub)` workflow: `workflow_dispatch` placeholder with `if: ${{ false }}` until SSH keys and hosts secrets are wired; includes instructions plus sample commands.

### Drift guards
- Inputs commit-pinned in `flake.nix` + `flake.lock`.
- Host modules carry explicit compose/TLS/env overrides so staging cannot accidentally run prod config.
- Fail2ban identifier + Docker journald tagging tie HTTP bans to whichever container name the compose project emits.
- Secrets path + SOPS hook remove `.env` scp drift and keep permissions deterministic.
