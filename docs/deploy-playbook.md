## Deploy Playbook

### 0. Pre-flight
- Push your branch and wait for `Flake CI` to go green (runs `nix flake check` + both host builds on `main/master/dev`).
- Review `docs/reality-check.md` to confirm no host/module drift appeared since your last deploy.

### 1. Stage (`test-server`)
```bash
ssh app@test-server
sudo nixos-rebuild switch --flake /etc/nixos#test-server
sudo systemctl status impious-stack
sudo journalctl -u impious-stack -n 200 -f
```
- Expect `CADDY_TLS_MODE=disabled` and fake domains per `hosts/test-server.nix`.
- Verify HTTP 200s from Caddy (TLS off) and watch fail2ban for noisy clients:
  ```bash
  sudo fail2ban-client status caddy-http
  ```

### 2. Promote (`vps`)
```bash
ssh app@impious-vps
sudo nixos-rebuild switch --flake /etc/nixos#vps
sudo systemctl status impious-stack
sudo journalctl -u impious-stack -n 200 -f
```
- Confirm `docker compose` pulled fresh images and `impious-stack` stayed green.
- Validate ACME: `journalctl -u impious-stack | grep -i acme`.

### 3. Post-checks
- `sudo nft list ruleset | grep http` – ensure firewall ports (`80/443`) open as expected.
- `sudo fail2ban-client status sshd` and `... caddy-http`.
- `docker system df` to watch disk usage; auto-prune runs weekly but prod deploys shouldn’t explode disk.

### 4. Rollback
If staging reveals a bad closure:
```bash
sudo nixos-rebuild switch --rollback
```
Repeat on production only after staging is healthy.

### 5. GitOps expectations
- Every deploy comes from a merged PR referencing CI run IDs.
- Manual SSH rebuilds are temporary; wire the `.github/workflows/deploy-stub.yml` once secrets exist to automate over SSH with `nix copy`.
