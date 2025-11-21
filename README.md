# NixHQ Fortress

NixHQ is the single source of truth for the Impious VPS fleet. Each flake target
(`.#vps`, `.#test-server`) pulls in the same hardened base modules and then
layers host-specific overrides.

## Layout
- `flake.nix` – pins `nixpkgs` 25.05 + `sops-nix`, iterates the host map, and passes shared modules.
- `flake.lock` – records the exact commits for every input.
- `configuration.nix` – imports the hardened module stack plus the `sops-nix` module.
- `modules/common/` – `system.nix`, `security.nix`, `docker.nix`, and the typed `services.impiousStack` module.
- `modules/users/app-user.nix` – defines the locked-down deploy user (`app`).
- `hosts/*.nix` – host toggles (compose file, TLS mode, domains, fail2ban identifier, staging env vars).
- `hardware-*.nix` – generated hardware profiles per VPS.
- `docs/` – recon, secrets runbook, deploy playbook, infra reality report.
- `.github/workflows/` – flake CI, Cursor review automation, and a gated deploy stub.

## Pinning & Updates
Run the standard dance whenever you need a new upstream commit:

```bash
. ~/.nix-profile/etc/profile.d/nix.sh   # if nix not on PATH
nix --extra-experimental-features 'nix-command flakes' flake update
nix flake metadata                      # confirm the new revisions
```

Always include the `flake.lock` diff in PRs and highlight the commit hashes in
your change summary to prove drift control.

## Operate
Follow `docs/deploy-playbook.md` for staging-first rebuilds and host
verification commands. Recon and architecture notes live in
`docs/infra-reality.md`, while the raw baseline dump sits in
`docs/reality-check.md`.

## Secrets
Secrets never ride in git. Model required keys in `.env.example`, encrypt the
live values with SOPS, and point `services.impiousStack.secretSopsFile` at the
encrypted payload. The module fans the decrypted file in with `0600` perms and
feeds it into `EnvironmentFile=`. Full details: `docs/secrets.md`.
