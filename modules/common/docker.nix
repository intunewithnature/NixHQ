{ lib, pkgs, ... }:

let
  deployRoot = "/opt/impious";
  mkDirRule = dir: "d ${dir} 0750 app docker -";
in
{
  ###################################### Docker ########################################
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker;

    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--volumes" ];
    };

    daemon.settings = {
      "log-driver" = "journald";
      "live-restore" = true;
    };
  };

  ################################### Host Directories ##################################
  systemd.tmpfiles.rules = lib.mkAfter [
    (mkDirRule deployRoot)
  ];

  ################################ Docker Tooling #######################################
  environment.systemPackages = with pkgs; [
    docker
    docker-compose
  ];

  environment.etc."docker/cli-plugins/docker-compose".source =
    "${pkgs.docker-compose}/lib/docker/cli-plugins/docker-compose";
}
