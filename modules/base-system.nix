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
  services.journald.extraConfig = ''
    Storage=persistent
    SystemMaxUse=1G
    RuntimeMaxUse=256M
    SystemKeepFree=512M
    SystemMaxFileSize=256M
  '';

  ################################### Time Sync #########################################
  services.chrony.enable = true;

  ############################ System Packages (Global) #################################
  environment.systemPackages = with pkgs; [
    git
    nano
    htop
    docker
    docker-compose
    nftables
  ];

  #################################### Flake Support ###################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  ################################ System State Version ################################
  system.stateVersion = "25.05";
}
