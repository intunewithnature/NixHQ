{ ... }:

{
  networking.hostName = "test-server";

  services.impiousStack = {
    enable = true;
    environment = "staging";
    composeFile = "docker-compose.dev.yml";
    projectName = "impious-staging";
  };
}
