{ config, lib, pkgs, ... }:

let
  # Adjust this when you actually create the staging stack.
  # For imperiumsolis.org you might later set:
  #   stagingDir = "/opt/imperiumsolis/deploy";
  stagingDir = "/opt/staging/deploy";
in
{
  systemd.services.caddy-stack = {
    description = "Caddy (reverse proxy) Docker stack (staging)";

    wantedBy = [ "multi-user.target" ];

    after    = [ "network-online.target" "docker.service" ];
    requires = [ "network-online.target" "docker.service" ];

    # If the directory doesn't exist, systemd will just skip the unit
    # instead of failing the boot with a CHDIR error.
    unitConfig = {
      ConditionPathExists = stagingDir;
    };

    serviceConfig = {
      WorkingDirectory = stagingDir;
      ExecStart        = "${pkgs.docker-compose}/bin/docker-compose up -d";
      ExecStop         = "${pkgs.docker-compose}/bin/docker-compose down";
      Type             = "oneshot";
      RemainAfterExit  = true;
    };
  };
}
