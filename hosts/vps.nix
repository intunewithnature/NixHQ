{ ... }:

{
  networking.hostName = "impious-vps";

  services.impiousStack = {
    enable = true;
    environment = "production";
    composeFile = "docker-compose.yml";
    projectName = "impious-prod";
  };
}
