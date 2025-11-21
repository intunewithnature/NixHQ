## Reality Check — 2025-11-21

### Hosts + Imports
- `flake.nix` maps `.#vps` and `.#test-server` to their hardware + role modules and feeds the shared imports via `configuration.nix`.

```4:37:flake.nix
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    sops-nix.url = "github:Mic92/sops-nix";
  };

  outputs = inputs@{ nixpkgs, ... }:
    let
      inherit (nixpkgs) lib;
      system = "x86_64-linux";
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
              inherit system;
              modules = [
                ./configuration.nix
                host.hardware
                host.role
              ];
              specialArgs = { inherit inputs; };
            })
          hosts;
    };
```

### Common Module Stack
- `configuration.nix` imports `sops-nix` plus the shared system, security, docker, impious-stack, and `app` user modules.

```1:15:configuration.nix
{ inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
    ./modules/common/system.nix
    ./modules/common/security.nix
    ./modules/common/docker.nix
    ./modules/common/impious-stack.nix
    ./modules/users/app-user.nix
  ];

  system.stateVersion = "25.05";
}
```

### Impious Stack Wiring
- `modules/common/impious-stack.nix` defines typed options for the deployment directory, compose file, TLS mode, domains, static asset directories, secrets contract, and fail2ban identifier, then builds the hardening for `systemd.services.impious-stack`.

```36:210:modules/common/impious-stack.nix
  options.services.impiousStack = {
    enable = mkOption { type = types.bool; default = false; };
    deployDir = mkOption { type = types.str; default = "/opt/impious/deploy"; };
    composeFile = mkOption { type = types.str; default = "docker-compose.yml"; };
    tlsMode = mkOption { type = types.enum [ "enabled" "disabled" ]; default = "enabled"; };
    primaryDomain = mkOption { type = types.str; default = "impious.io"; };
    domains = mkOption { type = types.listOf types.str; default = [ ]; };
    staticDirs = mkOption { type = types.attrsOf types.str; default = { }; };
    secretEnvFile = mkOption { type = types.str; default = "/var/lib/impious-stack/secrets/stack.env"; };
    secretSopsFile = mkOption { type = types.nullOr types.path; default = null; };
    manageSecretFile = mkOption { type = types.bool; default = true; };
    extraEnvFiles = mkOption { type = types.listOf types.str; default = [ ]; };
    fail2banIdentifier = mkOption { type = types.str; default = "impious-caddy"; };
  };

  systemd.services.impious-stack = {
    wantedBy = [ "multi-user.target" ];
    after = [ "network-online.target" "docker.service" ];
    requires = [ "network-online.target" "docker.service" ];
    unitConfig.ConditionPathExists = cfg.deployDir;
    environment = {
      COMPOSE_FILE = cfg.composeFile;
      COMPOSE_PROJECT_NAME = cfg.projectName;
      IMPIOUS_ENVIRONMENT = cfg.environment;
      CADDY_PRIMARY_DOMAIN = cfg.primaryDomain;
      CADDY_DOMAINS = concatStringsSep "," cfg.domains;
      CADDY_TLS_MODE = cfg.tlsMode;
    } // staticEnv // cfg.extraEnvironment;
    environmentFiles = [ cfg.secretEnvFile ] ++ cfg.extraEnvFiles;
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${composeBin} compose --project-name ${cfg.projectName} --file ${cfg.composeFile} up -d --force-recreate --remove-orphans";
      ExecStop = "${composeBin} compose --project-name ${cfg.projectName} --file ${cfg.composeFile} down";
      AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
      CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
      ProtectSystem = "strict";
      SyslogIdentifier = cfg.fail2banIdentifier;
    };
  };

  sops.secrets.impious-stack-env = {
    sopsFile = cfg.secretSopsFile;
    path = cfg.secretEnvFile;
    owner = cfg.user;
    group = cfg.group;
    mode = "0600";
    format = "dotenv";
  };
```

### Security Surface
- Firewall, SSH, sudo, and fail2ban hardening lives in `modules/common/security.nix`.

```10:70:modules/common/security.nix
  security.sudo.enable = true;

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = lib.mkDefault [ 443 ];
    logRefusedConnections = true;
  };

  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitEmptyPasswords = "no";
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AllowTcpForwarding = "no";
      X11Forwarding = "no";
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      AllowUsers = "app";
    };
    extraConfig = "AllowUsers app";
  };

  services.fail2ban = {
    enable = true;
    package = pkgs.fail2ban;
    jails = {
      DEFAULT.settings = {
        backend = "systemd";
        banaction = lib.mkForce "nftables-multiport";
        findtime = "15m";
        bantime = "1h";
        maxretry = 5;
      };
      sshd.settings = {
        enabled = true;
        port = "ssh";
        logpath = "/var/log/auth.log";
      };
    }
    // lib.optionalAttrs stackCfg.enable {
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

### Docker + Base System
- `modules/common/docker.nix` enables Docker with journald logging and weekly prune jobs; `modules/common/system.nix` keeps the boot loader, swapfile, timezone, journald persistence, and base packages consistent; `modules/users/app-user.nix` defines the `app` deploy user with SSH keys.

### Pinning Status
- `flake.lock` pins `nixpkgs` (25.05) at `c58bc7f5459328e4afac201c5c4feb7c818d604b` and `sops-nix` at `877bb495a6f8faf0d89fc10bd142c4b7ed2bcc0b`. Always inspect the lock alongside `flake.nix` for drift.

### CI / CD
- `Flake CI` runs on pushes/PRs to `main`, `master`, `dev`, installs a pinned Nix, runs `nix flake check`, and builds both host closures. `deploy-stub` remains disabled (`if: ${{ false }}`) until secrets land; `cursor-code-review` integrates Cursor once the API key is added.

```1:40:.github/workflows/flake-check.yml
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
          nix_path: nixpkgs=github:NixOS/nixpkgs/c58bc7f5459328e4afac201c5c4feb7c818d604b
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
- No encrypted dotenvs are committed; operators must set `services.impiousStack.secretSopsFile` per host to actually provision secrets.
- Docker Compose still relies on the source repo to emit journald logs tagged with `fail2banIdentifier`; if the compose file omits that logging config the HTTP jail never triggers.
- GitHub CI references a hard-coded `nixpkgs` commit; keep it in sync with `flake.lock` when the pin changes.
- `deploy-stub` is intentionally disabled until SSH keys and secrets are wired in, so deployments stay manual for now.
