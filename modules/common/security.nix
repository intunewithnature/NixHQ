{ config, lib, ... }:

let
  inherit (lib) optionalAttrs;
  stackCfg = config.services.impiousStack;
in
{
  #################################### Networking #####################################
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    logRefusedConnections = true;
  };

  ###################################### Sudo ##########################################
  security.sudo = {
    enable = true;
    wheelNeedsPassword = true;
  };

  ###################################### SSH ###########################################
  services.openssh = {
    enable = true;
    settings = {
      PermitEmptyPasswords = false;
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AuthenticationMethods = "publickey";
      AllowAgentForwarding = false;
      AllowTcpForwarding = false;
      X11Forwarding = false;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      LoginGraceTime = "30s";
      MaxSessions = 4;
      MaxStartups = "10:30:60";
      GSSAPIAuthentication = false;
      PubkeyAuthentication = true;
    };
    openFirewall = false;
    extraConfig = "AllowUsers app";
  };

  #################################### Security ########################################
  services.fail2ban = {
    enable = true;

    jails = {
      DEFAULT.settings = {
        backend = "systemd";
        banaction = lib.mkForce "nftables-multiport";
        findtime = "15m";
      };

      sshd.settings = {
        enabled = true;
        port = "ssh";
        filter = "sshd";
        maxretry = 5;
        bantime = "15m";
      };
    }
    // optionalAttrs stackCfg.enable {
      "caddy-http".settings = {
        enabled = true;
        backend = "systemd";
        journalmatch = "SYSLOG_IDENTIFIER=${stackCfg.fail2banIdentifier}";
        maxretry = 20;
        findtime = "10m";
        bantime = "15m";
        port = "http,https";
        protocol = "tcp";
        action = "nftables-multiport[name=caddy-http, port=\"80,443\", protocol=tcp]";
        failregex = ''
          <HOST> .*"(GET|POST|HEAD|PUT|DELETE|PATCH|OPTIONS) [^"]+" (40\d|41\d|42\d|43\d|44\d|50\d|51\d|52\d|53\d)
        '';
      };
    };
  };
}
