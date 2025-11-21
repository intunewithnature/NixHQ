{ ... }:

{
  networking.hostName = "test-server";

  services.impiousStack = {
    enable = true;
    environment = "staging";
    composeFile = "docker-compose.dev.yml";
    projectName = "impious-staging";
    tlsMode = "disabled";
    primaryDomain = "impious.test";
    domains = [
      "impious.test"
      "www.impious.test"
      "game.impious.test"
      "imperiumsolis.test"
      "www.imperiumsolis.test"
      "codex.impious.test"
      "codex.imperiumsolis.test"
    ];
    staticDirs = {
      site = "/opt/impious/deploy/site";
      codex = "/opt/impious/deploy/codex/public";
    };
    extraEnvironment = {
      CADDY_STAGING_NOTE = "use_fake_domains";
    };
    fail2banIdentifier = "impious-staging-caddy";
  };
}
