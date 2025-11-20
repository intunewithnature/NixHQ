# NixHQ Fortress

NixHQ is the single source of truth for the Impious VPS fleet. Each host is expressed as a flake target (`.#vps`, `.#test-server`) composed from the common modules under `modules/`.

## Layout
- `flake.nix` – pins `nixpkgs` + `sops-nix`, exports NixOS configs for every host.
- `configuration.nix` – shared imports (`system`, `security`, `docker`, `impious-stack`, `app-user`).
- `modules/common/` – hardening, Docker engine tuning, the typed `services.impiousStack` module.
- `modules/users/app-user.nix` – locked-down deploy user (`app`).
- `hosts/*.nix` – host-specific toggles (compose file, TLS mode, domains, fail2ban identifiers).
- `docs/` – recon, secrets runbook, deploy playbook, infra reality report.
- `.github/workflows/` – flake CI + a disabled CD stub for when secrets arrive.

## Pinning & Updates
`nixpkgs` is commit-pinned (`4c8cdd5b1a630e8f72c9dd9bf582b1afb3127d2c`). To bump it (or any other input):

```bash
. ~/.nix-profile/etc/profile.d/nix.sh   # if Nix is not already on PATH
nix --extra-experimental-features 'nix-command flakes' flake update nixpkgs
nix flake metadata                      # verify the lock diff
```

Always include the resulting `flake.lock` diff in PRs. Document the new commit in your change summary to prove drift control.

## Operate
Follow `docs/deploy-playbook.md` for staging-first rebuilds and host verification commands. Recon and architecture notes live in `docs/infra-reality.md`, while the raw baseline dump sits in `docs/reality-check.md`.

## Secrets
Secrets never ride in git. Model required keys in `.env.example`, encrypt the live values with SOPS, and point `services.impiousStack.secretSopsFile` at the encrypted payload. The module fans the decrypted file in with `0600` perms and feeds it into `EnvironmentFile=`. Full details: `docs/secrets.md`.
