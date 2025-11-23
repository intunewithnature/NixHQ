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
    deployDir = "/opt/impious/deploy";
    composeFile = "docker-compose.dev.yml";
    projectName = "impious-staging";
  };
}
