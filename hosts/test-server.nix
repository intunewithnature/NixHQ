{ ... }:

{
  imports = [
    ../configuration.nix
    ../hardware-test-server.nix
    ../modules/caddy-stack.nix
  ];

  networking.hostName = "test-server";

  services.caddyStack = {
    enable = true;
    environment = "staging";
    composeFile = "docker-compose.dev.yml";
  };
}
