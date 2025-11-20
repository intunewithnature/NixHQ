{ lib, ... }:
{
  ###################################### Docker ########################################
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--volumes" ];
    };

    daemon.settings = {
      "log-driver" = "json-file";
      "log-opts" = {
        "max-size" = "100m";
        "max-file" = "3";
      };
      "live-restore" = true;
    };
  };

  ################################### Host Directories ##################################
  systemd.tmpfiles.rules = lib.mkAfter [
    "d /opt/impious 0750 app docker -"
  ];
}
