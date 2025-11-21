## Secrets Playbook

The Impious stack never ships live credentials in this repo. All runtime secrets are injected through the `services.impiousStack.secretEnvFile` option, which defaults to `/var/lib/impious-stack/secrets/stack.env` and is readable only by the `app` user.

### 1. Model the keys
Update `.env.example` whenever the compose repo adds or removes keys. This file is intentionally value-less and simply documents the required variables for operators.

### 2. Wire up SOPS
1. Generate/rotate SOPS keys (`age` or GPG) and commit the `.sops.yaml` policy to the application repo.
2. Create an encrypted dotenv alongside the policy, e.g. `secrets/impious-stack.env`.
3. Point the host module at the encrypted payload:
   ```nix
   services.impiousStack = {
     secretSopsFile = ./secrets/impious-stack.env;
   };
   ```
4. `nixos-rebuild` will ask `sops-nix` to materialize the decrypted file at `secretEnvFile` with `0600` permissions, owned by `app:app`.

### 3. Local editing loop
```bash
sops secrets/impious-stack.env
```

SOPS writes plaintext to `$EDITOR`, then re-encrypts on save. Commit the encrypted file, never the plaintext result.

### 4. Runtime contract
- `systemd` adds `secretEnvFile` (and any `extraEnvFiles`) to `EnvironmentFile=...` for `impious-stack.service`.
- Staging/production hosts can override `secretEnvFile`, `secretSopsFile`, or `manageSecretFile` when blue/green rolling out.
- If `manageSecretFile = false`, the service still references `secretEnvFile` but expects the operator to provision it (useful for short-lived sandboxes).

Keeping secrets in Git-encrypted form plus deterministic permissions kills “scp the .env” drift and lets GitOps drive every deploy.
