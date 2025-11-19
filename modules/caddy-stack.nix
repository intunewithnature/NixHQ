{ config, lib, pkgs, ... }:

let
  inherit (lib) mkEnableOption mkIf mkOption types;

  cfg = config.services.caddyStack;
in
{
  options.services.caddyStack = {
    enable = mkEnableOption "the Caddy docker-compose stack";

    deployDir = mkOption {
      type = types.str;
      default = "/opt/impious/deploy";
      example = "/opt/impious/deploy";
      description = ''
        Absolute path to the directory containing the docker-compose.yml for the reverse proxy stack.
        The directory must exist on disk before the service starts.
      '';
    };

    environment = mkOption {
      type = types.enum [ "production" "staging" ];
      default = "production";
      description = "Human-readable label used in service descriptions and docs.";
    };
  };

  config = mkIf cfg.enable {
    systemd.services.caddy-stack = {
      description = "Caddy (reverse proxy) Docker stack (${cfg.environment})";

      wantedBy = [ "multi-user.target" ];
      after    = [ "network-online.target" "docker.service" ];
      requires = [ "network-online.target" "docker.service" ];

      unitConfig.ConditionPathExists = cfg.deployDir;

      serviceConfig = {
        WorkingDirectory = cfg.deployDir;
        ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
        ExecStop  = "${pkgs.docker-compose}/bin/docker-compose down";
        Type = "oneshot";
        RemainAfterExit = true;
      };
    };
  };
}
