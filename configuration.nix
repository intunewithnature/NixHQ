{ config, lib, pkgs, ... }:

{
  #################################### Boot Loader ####################################
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  #################################### Networking #####################################
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  ###################################### Swap #########################################
  # Shared choice: 2G swapfile on both hosts
  swapDevices = [
    { device = "/swapfile"; size = 2048; }
  ];

  ###################################### Timezone ######################################
  time.timeZone = "America/Detroit";

  ################################### System Logs ######################################
  services.journald.extraConfig = ''Storage=persistent'';

  #################################### Users ###########################################
  users.users.app = {
    isNormalUser = true;
    description = "App deployment user";
    home = "/home/app";
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" "docker" ];

    openssh.authorizedKeys.keys = [
      # same key you had before – replace if needed
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACt+4DDr57ov4803wmOWqw3umfSFPjTMHUTNNNvr0By eddsa-key-20251115"
    ];
  };

  ###################################### Sudo ##########################################
  security.sudo.enable = true;

  ###################################### SSH ###########################################
  services.openssh = {
    enable = true;

    settings = {
      PermitEmptyPasswords = "no";
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };

    # Only allow app over SSH
    extraConfig = "AllowUsers app";
  };

  #################################### Security ########################################
  services.fail2ban.enable = true;

  ###################################### Docker ########################################
  virtualisation.docker = {
    enable = true;
    autoPrune.enable = true;
  };

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
