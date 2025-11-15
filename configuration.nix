{ config, lib, pkgs, ... }:

{
  imports =
    [
      ./hardware-configuration.nix
    ];

  # Boot loader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  # Basic networking
  networking.hostName = "nixos";

  # Firewall: on, SSH only for now
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 ];
  };

  # Time zone
  time.timeZone = "America/Detroit";

  # App user with SSH key and sudo
  users.users.app = {
    isNormalUser = true;
    description = "App deployment user";
    home = "/home/app";
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACt+4DDr57ov4803wmOWqw3umfSFPjTMHUTNNNvr0By eddsa-key-20251115"
    ];
  };

  # OpenSSH daemon
  services.openssh = {
    enable = true;
    settings = {
      PermitEmptyPasswords = "no";
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Packages installed system-wide
  environment.systemPackages = with pkgs; [
    git
    nano
    htop
  ];

  # NixOS compatibility version for this machine
  system.stateVersion = "25.05"; # Did you read the comment?
}
