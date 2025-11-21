## Infra Reality — Hardened Stack

### Hosts at a glance
- `.#vps` → `hosts/vps.nix` (production): `docker-compose.yml`, TLS enabled, `primaryDomain = "impious.io"`, fail2ban identifier `impious-prod-caddy`.
- `.#test-server` → `hosts/test-server.nix` (staging): `docker-compose.dev.yml`, TLS disabled, fake `.test` domains, `staticDirs` for `site` and `codex`, extra env `CADDY_STAGING_NOTE`, fail2ban identifier `impious-staging-caddy`.
- Both share hardware profiles (`hardware-*.nix`) and the common module set from `configuration.nix`.

### Typed impious stack module
`modules/common/impious-stack.nix` introduces `services.impiousStack`:
- Enforces `deployDir`, typed TLS/domain/project settings, and appends host overrides (`composeFile`, `projectName`, `tlsMode`, `primaryDomain`, `domains`, `extraEnvironment`, `staticDirs`, `fail2banIdentifier`).
- Creates tmpfiles entries for `/opt/impious/deploy`, every declared static directory, and the secrets directory (owned by `app:docker` by default).
- Ones-shot `systemd` unit runs `docker compose up -d --force-recreate --remove-orphans`/`down`, waits for Docker + network, pins `SyslogIdentifier` to the fail2ban tag, and runs with `CAP_NET_BIND_SERVICE`, `ProtectSystem=strict`, `NoNewPrivileges`.
- Secrets contract: `secretEnvFile`, `secretSopsFile`, `manageSecretFile`, `extraEnvFiles`. If `secretSopsFile` is set the `sops-nix` module renders the decrypted dotenv at deploy time.

### Docker substrate
`modules/common/docker.nix`:
- Enables Docker with weekly `autoPrune` (`--all --volumes`) to keep disk pressure low.
- Forces journald logging (`mode=non-blocking`, `max-buffer-size=8m`, tag = `{{.Name}}`) plus `live-restore` for daemon restarts.
- Ensures `/opt/impious` exists and stays owned by `app:docker`.

### Security posture
- Firewall: nftables with TCP 22/80/443, UDP 443 defaults, refused packets logged.
- SSH: `PermitRootLogin no`, key-only auth, forwarding disabled, `AllowUsers app`, keep-alive limits to kill idle tunnels.
- Fail2ban:
  - Default sshd jail (systemd backend, nftables multiport banaction).
  - Optional `caddy-http` jail keyed off `services.impiousStack.fail2banIdentifier` watching journald HTTP errors.
- `app` user lives in its own group, belongs to `wheel` + `docker`, and owns every secret path.

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
