{ config, lib, pkgs, ... }:

let
  workingDir = "/opt/impious/deploy";
in
{
  systemd.services.caddy-stack = {
    description = "Caddy (reverse proxy) Docker stack (production)";

    wantedBy = [ "multi-user.target" ];

    # Fix the ordering warning: we both depend on and start after network-online.
    after    = [ "network-online.target" "docker.service" ];
    requires = [ "network-online.target" "docker.service" ];

    serviceConfig = {
      WorkingDirectory = workingDir;
      ExecStart        = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop         = "${pkgs.docker-compose}/bin/docker-compose down";
      Type             = "oneshot";
      RemainAfterExit  = true;
    };
  };
}
