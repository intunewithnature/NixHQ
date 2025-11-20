{ config, lib, pkgs, ... }:

let
  inherit (lib) mkOption types;
  cfg = config.deploy.appUser;
in
{
  options.deploy.appUser = {
    authorizedKeys = mkOption {
      type = types.listOf types.str;
      default = [
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIACt+4DDr57ov4803wmOWqw3umfSFPjTMHUTNNNvr0By eddsa-key-20251115"
      ];
      description = ''
        SSH public keys allowed to log in as the deployment user.
        Override per host to rotate keys without touching the shared module.
      '';
    };
  };

  config.users.users.app = {
    isNormalUser = true;
    description = "App deployment user";
    home = "/home/app";
    shell = pkgs.bashInteractive;
    extraGroups = [ "wheel" "docker" ];
    openssh.authorizedKeys.keys = cfg.authorizedKeys;
  };
}
