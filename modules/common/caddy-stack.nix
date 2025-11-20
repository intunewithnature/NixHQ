{ config, lib, pkgs, ... }:

let
  inherit (lib) mkAfter mkEnableOption mkIf mkOption optionalAttrs types;
  cfg = config.services.impiousStack;

  mkRule = path: "d ${path} 0750 ${cfg.user} ${cfg.group} -";
  managedDirs = [ cfg.deployDir ] ++ map (dir: "${cfg.deployDir}/${dir}") cfg.staticDirs;
  composeBin = "${pkgs.docker}/bin/docker";
in
{
  options.services.impiousStack = {
    enable = mkEnableOption "the impious Docker + Caddy compose stack";

    deployDir = mkOption {
      type = types.str;
      default = "/opt/impious/deploy";
      description = ''
        Absolute path to the directory containing the docker compose project used for
        the public-facing reverse proxy.
      '';
    };

    composeFile = mkOption {
      type = types.str;
      default = "docker-compose.yml";
      description = "Compose file name, relative to deployDir.";
    };

    projectName = mkOption {
      type = types.str;
      default = "impious-stack";
      description = "Value passed into COMPOSE_PROJECT_NAME.";
    };

    environment = mkOption {
      type = types.enum [ "production" "staging" ];
      default = "production";
      description = "Human-friendly label shown in the systemd unit description.";
    };

    user = mkOption {
      type = types.str;
      default = "app";
      description = "User that owns and runs docker compose.";
    };

    group = mkOption {
      type = types.str;
      default = "docker";
      description = "Primary group applied to docker compose processes.";
    };

    staticDirs = mkOption {
      type = types.listOf types.str;
      default = [ "site" "codex" ];
      example = [ "site" "codex" "assets" ];
      description = ''
        Subdirectories created under deployDir for static asset bind mounts.
        The application repository is responsible for mounting
        /opt/impious/deploy/site -> /srv/site (impious.io) and
        /opt/impious/deploy/codex -> /srv/codex (codex.imperiumsolis.com) within its Caddy compose file.
      '';
    };

    environmentFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "EnvironmentFile entries consumed by the systemd unit.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.deployDir != "";
        message = "services.impiousStack.deployDir must not be empty.";
      }
    ];

    systemd.tmpfiles.rules = mkAfter (map mkRule managedDirs);

    systemd.services.impious-stack = {
      description = "Impious Docker stack (${cfg.environment})";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "docker.service" ];
      requires = [ "network-online.target" "docker.service" ];
      unitConfig.ConditionPathExists = cfg.deployDir;
      startLimitIntervalSec = 60;
      startLimitBurst = 3;

      environment = {
        COMPOSE_FILE = cfg.composeFile;
        COMPOSE_PROJECT_NAME = cfg.projectName;
        DEPLOY_ENV = cfg.environment;
      };

      serviceConfig =
        {
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = cfg.deployDir;
          ExecStart = "${composeBin} compose up -d --force-recreate --remove-orphans";
          ExecReload = "${composeBin} compose up -d --force-recreate --remove-orphans";
          ExecStop = "${composeBin} compose down";
          Restart = "on-failure";
          RestartSec = 10;
          TimeoutStopSec = 300;
          KillMode = "mixed";
          StandardOutput = "journal";
          StandardError = "journal";
          UMask = "0027";
        }
        // optionalAttrs (cfg.environmentFiles != [ ]) {
          EnvironmentFile = cfg.environmentFiles;
        };
    };
  };
}
