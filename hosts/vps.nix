{ ... }:

{
  networking.hostName = "impious-vps";

  services.impiousStack = {
    enable = true;
    environment = "production";
    composeFile = "docker-compose.yml";
    projectName = "impious-prod";
    tlsMode = "enabled";
    primaryDomain = "impious.io";
    fail2banIdentifier = "impious-prod-caddy";
  };

  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 443 ];
  };

}
