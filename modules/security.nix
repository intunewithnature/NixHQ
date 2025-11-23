{ lib, ... }:

let
  inherit (lib) mkForce;
in
{
  #################################### Networking #####################################
  networking.firewall = {
    enable = true;
    allowedTCPPorts = [ 22 80 443 ];
    allowedUDPPorts = [ 443 ];
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
    };

    extraConfig = "AllowUsers app";
  };

  #################################### Security ########################################
  services.fail2ban = {
    enable = true;

    jails = {
      DEFAULT.settings = {
        backend = "systemd";
        banaction = mkForce "nftables-multiport";
        findtime = "15m";
      };

      sshd.settings = {
        enabled = true;
        port = "ssh";
        filter = "sshd";
        maxretry = 5;
        bantime = "15m";
      };
    };
  };
}
