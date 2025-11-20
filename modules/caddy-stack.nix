{ config, lib, pkgs, ... }:

let
  inherit (lib) mkAfter mkEnableOption mkIf mkOption optionals types;
  cfg = config.services.caddyStack;
in
{
  options.services.caddyStack = {
    enable = mkEnableOption "the Caddy docker-compose stack";

    deployDir = mkOption {
      type = types.str;
      default = "/opt/impious/deploy";
      description = ''
        Absolute path to the directory containing the docker-compose project for the reverse proxy stack.
      '';
    };

    environment = mkOption {
      type = types.enum [ "production" "staging" ];
      default = "production";
      description = "Human-readable label used in service descriptions and docs.";
    };

    composeFile = mkOption {
      type = types.str;
      default = "docker-compose.yml";
      description = "Name of the compose file relative to deployDir.";
    };

    user = mkOption {
      type = types.str;
      default = "app";
      description = "Systemd User= that owns the compose process.";
    };

    group = mkOption {
      type = types.str;
      default = "docker";
      description = "Primary group used for the compose process.";
    };

    manageDeployDir = mkOption {
      type = types.bool;
      default = true;
      description = ''
        If set, ensure deployDir exists with sane permissions via systemd-tmpfiles.
      '';
    };

    environmentFiles = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = "Optional EnvironmentFile entries passed to the systemd unit.";
    };

    projectName = mkOption {
      type = types.str;
      default = "caddy-stack";
      description = "Value passed via COMPOSE_PROJECT_NAME.";
    };
  };

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.deployDir != "";
        message = "services.caddyStack.deployDir must not be empty.";
      }
    ];

    systemd.tmpfiles.rules = mkAfter (optionals cfg.manageDeployDir [
      "d ${cfg.deployDir} 0750 ${cfg.user} ${cfg.group} -"
    ]);

    systemd.services.caddy-stack = {
      description = "Caddy (reverse proxy) Docker stack (${cfg.environment})";

      wantedBy = [ "multi-user.target" ];
      after    = [ "network-online.target" "docker.service" ];
      requires = [ "network-online.target" "docker.service" ];

      unitConfig.ConditionPathExists = cfg.deployDir;

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        WorkingDirectory = cfg.deployDir;
        Environment = [
          "COMPOSE_FILE=${cfg.composeFile}"
          "COMPOSE_PROJECT_NAME=${cfg.projectName}"
        ];
        EnvironmentFile = cfg.environmentFiles;

        ExecStart = "${pkgs.docker-compose}/bin/docker-compose -f ${cfg.composeFile} up --remove-orphans";
        ExecReload = "${pkgs.docker-compose}/bin/docker-compose -f ${cfg.composeFile} up --remove-orphans";
        ExecStop = "${pkgs.docker-compose}/bin/docker-compose -f ${cfg.composeFile} down";

        Type = "simple";
        Restart = "on-failure";
        RestartSec = 5;
        TimeoutStopSec = 300;
        KillMode = "mixed";
      };
    };
  };
}
