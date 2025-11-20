{ ... }:

{
  networking.hostName = "test-server";

  services.impiousStack = {
    enable = true;
    environment = "staging";
    composeFile = "docker-compose.dev.yml";
    projectName = "impious-staging";
    tlsMode = "disabled";
    primaryDomain = "staging.impious.invalid";
    extraEnvironment = {
      CADDY_STAGING_NOTE = "use_fake_domains";
    };
    fail2banIdentifier = "impious-staging-caddy";
  };
}
