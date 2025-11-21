{ config, lib, pkgs, ... }:

let
  stackCfg = config.services.impiousStack or {
    enable = false;
    fail2banIdentifier = "impious-caddy";
  };
in
{
  ###################################### Sudo ##########################################
  security.sudo.enable = true;

  #################################### Networking #####################################
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = lib.mkDefault [ 443 ];
    logRefusedConnections = true;
  };

  ###################################### SSH ###########################################
  services.openssh = {
    enable = true;
    openFirewall = false;
    settings = {
      PermitEmptyPasswords = "no";
      PermitRootLogin = "no";
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      AllowTcpForwarding = false;
      X11Forwarding = false;
      ClientAliveInterval = 300;
      ClientAliveCountMax = 2;
      AllowUsers = [ "app" ];
    };
    extraConfig = "AllowUsers app";
  };

  #################################### Security ########################################
  services.fail2ban = {
    enable = true;
    package = pkgs.fail2ban;
    jails = {
      DEFAULT.settings = {
        backend = "systemd";
        banaction = lib.mkForce "nftables-multiport";
        findtime = lib.mkForce "15m";
        bantime = lib.mkForce "1h";
        maxretry = lib.mkForce 5;
      };
      sshd.settings = {
        enabled = true;
        port = "ssh";
        logpath = "/var/log/auth.log";
      };
    }
    // lib.optionalAttrs stackCfg.enable {
      "caddy-http".settings = {
        enabled = true;
        backend = "systemd";
        journalmatch = "SYSLOG_IDENTIFIER=${stackCfg.fail2banIdentifier}";
        maxretry = 10;
        findtime = "10m";
        bantime = "1h";
        failregex = ''
          <HOST> .*"(GET|POST|HEAD|PUT|DELETE|PATCH|OPTIONS) [^"]+" (40\d|41\d|42\d|43\d|44\d|50\d|51\d|52\d|53\d)
        '';
      };
    };
  };
}
