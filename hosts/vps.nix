{ ... }:

{
  imports = [
    ../configuration.nix
    ../hardware-vps.nix
    ../modules/caddy-stack.nix
  ];

  networking.hostName = "impious-vps";

  services.caddyStack = {
    enable = true;
    environment = "production";
    composeFile = "docker-compose.yml";
  };
}
