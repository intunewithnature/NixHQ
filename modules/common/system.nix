{ lib, pkgs, ... }:

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
  services.journald.extraConfig = lib.mkForce ''
    Storage=persistent
    SystemMaxUse=1G
    SystemMaxFileSize=250M
    RuntimeMaxUse=250M
  '';

  ############################ System Packages (Global) #################################
  environment.systemPackages = with pkgs; [
    git
    nano
    htop
  ];

  #################################### Flake Support ###################################
  nix.settings.experimental-features = [ "nix-command" "flakes" ];

  ################################ System State Version ################################
  system.stateVersion = "25.05";
}
