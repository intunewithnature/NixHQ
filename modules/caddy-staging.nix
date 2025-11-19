{ config, lib, pkgs, ... }:

let
  deployDir = "/opt/impious/deploy";
in
{
  systemd.services.caddy-stack = {
    description = "Caddy (reverse proxy) Docker stack (staging)";

    wantedBy = [ "multi-user.target" ];

    after    = [ "network-online.target" "docker.service" ];
    requires = [ "network-online.target" "docker.service" ];

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
