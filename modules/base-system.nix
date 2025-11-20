{ pkgs, ... }:

{
  #################################### Boot Loader ####################################
  boot.loader.grub = {
    enable = true;
    device = "/dev/vda";
  };

  ###################################### Swap #########################################
  swapDevices = [
    {
      device = "/swapfile";
      size = 2048;
    }
  ];

  ###################################### Timezone ######################################
  time.timeZone = "America/Detroit";

  ################################### System Logs ######################################
  services.journald.extraConfig = ''Storage=persistent'';

  ############################ System Packages (Global) #################################
  environment.systemPackages = with pkgs; [
    git
    nano
    htop
    docker-compose
  ];

  #################################### Flake Support ###################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  ################################ System State Version ################################
  system.stateVersion = "25.05";
}
