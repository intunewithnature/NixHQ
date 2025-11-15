{ config, lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
  ];

  # Boot loader
  boot.loader.grub.enable = true;
  boot.loader.grub.device = "/dev/vda";

  # Basic networking
  networking.hostName = "nixos";

  # Firewall: SSH + web ports (22, 80, 443)
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
  };

  # Swap file (2 GB)
  swapDevices = [
    { device = "/swapfile"; size = 2048; }
  ];

  # Time zone
  time.timeZone = "America/Detroit";

  # Persistent system logs
  services.journald.extraConfig = ''Storage=persistent'';

  # App user with SSH key and sudo
  users.users.app = {
    isNormalUser = true;
    description = "App deployment user";
    home = "/home/app";
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" ]; # later: [ "wheel" "docker" ] when Docker is on
    openssh.authorizedKeys.keys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACt+4DDr57ov4803wmOWqw3umfSFPjTMHUTNNNvr0By eddsa-key-20251115"
    ];
  };

  # Enable sudo for wheel
  security.sudo.enable = true;

  # OpenSSH daemon
  services.openssh = {
    enable = true;
    settings = {
      PermitEmptyPasswords = "no";
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
    # Only allow SSH as "app"
    extraConfig = "AllowUsers app";
  };

  # Basic brute-force protection
  services.fail2ban.enable = true;

  # Packages installed system-wide
  environment.systemPackages = with pkgs; [
    git
    nano
    htop
  ];

  # NixOS compatibility version for this machine
  system.stateVersion = "25.05";
}
