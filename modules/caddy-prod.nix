{ config, lib, pkgs, ... }:

let
  deployDir = "/opt/impious/deploy";
in
{
  systemd.services.caddy-stack = {
    description = "Caddy (reverse proxy) Docker stack (production)";

    wantedBy = [ "multi-user.target" ];

    # Make sure network + Docker are up first
    after    = [ "network-online.target" "docker.service" ];
    requires = [ "network-online.target" "docker.service" ];

    # Only start if the deploy dir exists
    unitConfig = {
      ConditionPathExists = deployDir;
    };

    serviceConfig = {
      WorkingDirectory = deployDir;

      ExecStart = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop  = "${pkgs.docker-compose}/bin/docker-compose down";

      Type            = "oneshot";
      RemainAfterExit = true;
    };
  };
}
