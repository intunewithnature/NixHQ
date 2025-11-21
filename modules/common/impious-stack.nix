{ config, lib, pkgs, ... }:

with lib;

let
  cfg = config.services.impiousStack;

  staticEnv =
    mapAttrs'
      (name: path: {
        name = "IMPIOUS_STATIC_${strings.toUpper (replaceStrings [ "-" ] [ "_" ] name)}";
        value = path;
      })
      cfg.staticDirs;

  envFiles = [ cfg.secretEnvFile ] ++ cfg.extraEnvFiles;

  secretDir = builtins.dirOf cfg.secretEnvFile;

  baseTmpfiles = [
    "d ${cfg.deployDir} 2775 ${cfg.user} ${cfg.group} -"
    "d ${secretDir} 0750 ${cfg.user} ${cfg.group} -"
  ];

  staticTmpfiles =
    mapAttrsToList (_: path: "d ${path} 0755 ${cfg.user} ${cfg.group} -") cfg.staticDirs;

  placeholderSecretRule =
    optional
      (cfg.manageSecretFile && cfg.secretSopsFile == null)
      "f ${cfg.secretEnvFile} 0600 ${cfg.user} ${cfg.group} -";

  composeBin = "${pkgs.docker}/bin/docker";
in
{
  options.services.impiousStack = {
    enable = mkOption {
      type = types.bool;
      default = false;
      description = "Whether to manage the Impious Docker stack.";
    };

    user = mkOption {
      type = types.str;
      default = "app";
      description = "System user that owns the deployment directory and runs docker compose.";
    };

    group = mkOption {
      type = types.str;
      default = "docker";
      description = "Primary group that should own writable assets.";
    };

    environment = mkOption {
      type = types.enum [ "production" "staging" "development" ];
      default = "production";
      description = "Deployment environment name injected as IMPIOUS_ENVIRONMENT.";
    };

    deployDir = mkOption {
      type = types.str;
      default = "/opt/impious/deploy";
      description = "Directory containing the docker-compose project.";
    };

    composeFile = mkOption {
      type = types.str;
      default = "docker-compose.yml";
      description = "Compose file path relative to deployDir.";
    };

    projectName = mkOption {
      type = types.str;
      default = "impious";
      description = "Compose project name (maps to container prefixes).";
    };

    tlsMode = mkOption {
      type = types.enum [ "enabled" "disabled" ];
      default = "enabled";
      description = "Controls whether Caddy requests real ACME certs.";
    };

    primaryDomain = mkOption {
      type = types.str;
      default = "impious.io";
      description = "Primary HTTP domain used by Caddy.";
    };

    domains = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional HTTP domains for the stack.";
    };

    staticDirs = mkOption {
      type = types.attrsOf types.str;
      default = { };
      example = { site = "/opt/impious/deploy/site"; };
      description = "Static directories that should exist before compose runs.";
    };

    extraEnvironment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Extra environment variables injected into the service.";
    };

    secretEnvFile = mkOption {
      type = types.str;
      default = "/var/lib/impious-stack/secrets/stack.env";
      description = "Path to the dotenv file consumed by docker compose.";
    };

    secretSopsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional encrypted dotenv to materialize via sops-nix.";
    };

    manageSecretFile = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to ensure the secret env file exists (via SOPS or tmpfiles).";
    };

    extraEnvFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Additional EnvironmentFile= entries to include.";
    };

    fail2banIdentifier = mkOption {
      type = types.str;
      default = "impious-caddy";
      description = "Identifier used by fail2ban to hook journald logs.";
    };
  };

  config = mkMerge [
    (mkIf cfg.enable {
      systemd.tmpfiles.rules =
        baseTmpfiles
        ++ staticTmpfiles
        ++ placeholderSecretRule;

      systemd.services.impious-stack = {
        description = "Impious docker compose stack";
        wantedBy = [ "multi-user.target" ];
        after = [ "network-online.target" "docker.service" ];
        requires = [ "network-online.target" "docker.service" ];
        unitConfig.ConditionPathExists = cfg.deployDir;

        path = [ pkgs.coreutils pkgs.gnugrep pkgs.util-linux pkgs.docker ];

        environment =
          {
            COMPOSE_FILE = cfg.composeFile;
            COMPOSE_PROJECT_NAME = cfg.projectName;
            IMPIOUS_ENVIRONMENT = cfg.environment;
            CADDY_PRIMARY_DOMAIN = cfg.primaryDomain;
            CADDY_DOMAINS = concatStringsSep "," cfg.domains;
            CADDY_TLS_MODE = cfg.tlsMode;
            IMPIOUS_DEPLOY_DIR = cfg.deployDir;
          }
          // staticEnv
          // cfg.extraEnvironment;

        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.deployDir;
          SyslogIdentifier = cfg.fail2banIdentifier;
          ExecStart = "${composeBin} compose --project-name ${cfg.projectName} --file ${cfg.composeFile} up -d --force-recreate --remove-orphans";
          ExecStop = "${composeBin} compose --project-name ${cfg.projectName} --file ${cfg.composeFile} down";
          TimeoutStartSec = "5min";
          TimeoutStopSec = "120s";
          KillMode = "mixed";
          AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
          CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectHome = "read-only";
          ProtectSystem = "strict";
          ReadWritePaths = [
            cfg.deployDir
            "/var/lib/docker"
            "/run/docker.sock"
          ];
          EnvironmentFile = envFiles;
        };
      };
    })

    (mkIf (cfg.manageSecretFile && cfg.secretSopsFile != null) {
      sops.secrets.impious-stack-env = {
        sopsFile = cfg.secretSopsFile;
        path = cfg.secretEnvFile;
        owner = cfg.user;
        group = cfg.group;
        mode = "0600";
        format = "dotenv";
      };
    })
  ];
}
