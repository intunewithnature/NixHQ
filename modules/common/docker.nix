{ lib, pkgs, ... }:

{
  ###################################### Docker ########################################
  virtualisation.docker = {
    enable = true;
    package = pkgs.docker;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" "--force" "--volumes" ];
    };
    daemon.settings = {
      "log-driver" = "journald";
      "log-opts" = {
        "mode" = "non-blocking";
        "max-buffer-size" = "8m";
        "tag" = "{{.Name}}";
      };
      "live-restore" = true;
    };
  };

  ##################################### Directories #####################################
  systemd.tmpfiles.rules = [
    "d /opt/impious 0755 app docker -"
  ];
}
