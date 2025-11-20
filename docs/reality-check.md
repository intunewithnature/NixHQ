## Reality Check — 2025-11-20

### Hosts + Imports
- `flake.nix` maps two systems that all reuse the shared module stack in `configuration.nix`.

```14:34:flake.nix
      hosts = {
        vps = {
          hardware = ./hardware-vps.nix;
          role = ./hosts/vps.nix;
        };
        test-server = {
          hardware = ./hardware-test-server.nix;
          role = ./hosts/test-server.nix;
        };
      };
    in {
      nixosConfigurations =
        lib.mapAttrs
          (_: host:
            lib.nixosSystem {
              system = "x86_64-linux";
              modules = commonModules ++ [ host.hardware host.role ];
            })
          hosts;
```

- `configuration.nix` imports `modules/common/{system,security,docker,impious-stack}.nix` plus `modules/users/app-user.nix`.

```4:11:configuration.nix
{
  imports = [
    ./modules/common/system.nix
    ./modules/common/security.nix
    ./modules/common/docker.nix
    ./modules/common/impious-stack.nix
    ./modules/users/app-user.nix
  ];
}
```

### Impious Stack Wiring
- Module `modules/common/impious-stack.nix` defines typed options for `deployDir` (`types.path`), `composeFile`, TLS mode, journald fail2ban identifiers, and SOPS-backed secret/env file handling.
- Systemd service now runs with `CAP_NET_BIND_SERVICE`, `NoNewPrivileges`, and injects both secret + extra env files plus host-specific domains.

```33:215:modules/common/impious-stack.nix
  options.services.impiousStack = {
    deployDir = mkOption {
      type = types.path;
      default = "/opt/impious/deploy";
    };
    tlsMode = mkOption { type = types.enum [ "enabled" "disabled" ]; };
    fail2banIdentifier = mkOption { type = types.str; default = "impious-caddy"; };
    secretEnvFile = mkOption {
      type = types.path;
      default = "/var/lib/impious-stack/secrets/stack.env";
    };
    secretSopsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
    };
    extraEnvFiles = mkOption { type = types.listOf types.path; default = [ ]; };
  };

  systemd.services.impious-stack = {
    after = [ "network-online.target" "docker.service" ];
    environment = {
      COMPOSE_FILE = cfg.composeFile;
      CADDY_TLS_MODE = cfg.tlsMode;
    } // cfg.extraEnvironment;
    serviceConfig = {
      User = cfg.user;
      WorkingDirectory = deployDir;
      ExecStart = "${composeBin} compose up -d --force-recreate --remove-orphans";
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      NoNewPrivileges = true;
    } // optionalAttrs (envFiles != [ ]) {
      EnvironmentFile = envFiles;
    };
  };
```

### Security Surface
- Firewall locked to TCP 22/80/443 and logs refusals.
- SSH enforces key-only auth, bans root login, disables forwarding, and restricts to the `app` user.
- Fail2ban stacks the sshd jail with a journald-powered `caddy-http` jail keyed off whatever identifier `services.impiousStack.fail2banIdentifier` publishes (`impious-prod-caddy` or `impious-staging-caddy`).

```5:84:modules/common/security.nix
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    logRefusedConnections = true;
  };

  services.openssh = {
    enable = true;
    settings = {
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      AllowUsers = "app";
    };
    extraConfig = "AllowUsers app";
  };

  services.fail2ban = {
    enable = true;
    jails = {
      DEFAULT.settings = {
        backend = "systemd";
        banaction = lib.mkForce "nftables-multiport";
        findtime = "15m";
      };
      sshd.settings = {
        enabled = true;
        port = "ssh";
        maxretry = 5;
      };
    }
    // optionalAttrs stackCfg.enable {
      "caddy-http".settings = {
        enabled = true;
        backend = "systemd";
        journalmatch = "SYSLOG_IDENTIFIER=${stackCfg.fail2banIdentifier}";
        failregex = ''
          <HOST> .*"(GET|POST|HEAD|PUT|DELETE|PATCH|OPTIONS) [^"]+" (40\d|41\d|42\d|43\d|44\d|50\d|51\d|52\d|53\d)
        '';
      };
    };
  };
```

### Pinning Status
- `flake.nix` and `flake.lock` both pin `nixpkgs` to commit `4c8cdd5b1a630e8f72c9dd9bf582b1afb3127d2c`; `sops-nix` is locked at `877bb495a6f8faf0d89fc10bd142c4b7ed2bcc0b`.
- `README.md` now documents the `nix --extra-experimental-features 'nix-command flakes' flake update nixpkgs` dance so reviewers know how the pin moved.

### CI / CD
- `Flake CI` workflow now runs on `main`, `master`, and `dev`, installs a pinned Nix (`nixpkgs=github:NixOS/nixpkgs/4c8cdd...`), prints flake metadata, then runs `nix flake check` plus both host builds with `NIX_CONFIG: experimental-features = nix-command flakes`.
- `deploy-stub` workflow is `workflow_dispatch`-only with `if: ${{ false }}`; it documents the commands and secrets required to automate once SSH creds exist.
- Cursor code-review workflow still exists but requires its API key.

```1:38:.github/workflows/flake-check.yml
name: Flake CI
on:
  push:
    branches:
      - main
      - master
      - dev
  pull_request:
    branches:
      - main
      - master
      - dev

jobs:
  flake-check:
    runs-on: ubuntu-latest
    env:
      NIX_CONFIG: experimental-features = nix-command flakes
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
      - name: Install Nix
        uses: cachix/install-nix-action@v27
        with:
          nix_path: nixpkgs=github:NixOS/nixpkgs/4c8cdd5b1a630e8f72c9dd9bf582b1afb3127d2c
      - name: Verify locked inputs
        run: nix flake metadata
      - name: Run nix flake check
        run: nix flake check --print-build-logs
      - name: Build staging system
        run: nix build .#nixosConfigurations.test-server.config.system.build.toplevel --print-build-logs
      - name: Build production system
        run: nix build .#nixosConfigurations.vps.config.system.build.toplevel --print-build-logs
```

### Smells & Drift Risks
- Upstream GitHub branch `dev` still returns HTTP 404, so the CI triggers for `dev` are future-proofing only—no way to audit parity with `main` yet.
- The deploy workflow is intentionally disabled until SSH + SOPS secrets land in repo settings; manual `nixos-rebuild` is still required.
- Compose/Caddy logs must adopt the `services.impiousStack.fail2banIdentifier` journald tag (via Docker logging options) or the HTTP jail will never fire.
- Actual encrypted dotenv files are not included; operators must supply `secretSopsFile` per host to make the secrets contract real.
