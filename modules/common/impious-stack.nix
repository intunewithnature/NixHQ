{ config, lib, pkgs, ... }:

let
  inherit (builtins) dirOf;

  inherit (lib)
    concatStringsSep
    hasPrefix
    listToAttrs
    mapAttrs
    mapAttrsToList
    mkAfter
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    optional
    optionalAttrs
    types
    unique;

  inherit (lib.strings) toUpper;

  cfg = config.services.impiousStack;

  composeBin = "${pkgs.docker}/bin/docker";
  deployDir = toString cfg.deployDir;
  secretEnvFile = toString cfg.secretEnvFile;
  secretDir = dirOf secretEnvFile;

  mkRule = path: "d ${path} 0750 ${cfg.user} ${cfg.group} -";
  mkSecretRule = path: "d ${path} 0700 ${cfg.user} ${cfg.user} -";

  resolveStaticDir = dir:
    if hasPrefix "/" dir then dir else "${deployDir}/${dir}";

  resolvedStaticDirs = mapAttrs (_: resolveStaticDir) cfg.staticDirs;

  managedStaticDirs =
    builtins.concatMap
      (dir:
        let
          parent = dirOf dir;
        in
        if parent == dir then [ dir ] else [ dir parent ])
      (builtins.attrValues resolvedStaticDirs);

  managedDirs = unique ([ deployDir ] ++ managedStaticDirs);

  envFiles =
    [ secretEnvFile ]
    ++ map toString cfg.extraEnvFiles;
in
{
  options.services.impiousStack = {
    enable = mkEnableOption "the impious Docker + Caddy compose stack";

    deployDir = mkOption {
      type = types.path;
      default = "/opt/impious/deploy";
      description = ''
        Absolute path to the directory containing the docker compose project used for
        the public-facing reverse proxy.
      '';
    };

    composeFile = mkOption {
      type = types.str;
      default = "docker-compose.yml";
      description = "Compose file name, relative to deployDir.";
    };

    projectName = mkOption {
      type = types.str;
      default = "impious-stack";
      description = "Value passed into COMPOSE_PROJECT_NAME.";
    };

    environment = mkOption {
      type = types.enum [ "production" "staging" ];
      default = "production";
      description = "Human-friendly label shown in the systemd unit description.";
    };

    tlsMode = mkOption {
      type = types.enum [ "enabled" "disabled" ];
      default = "enabled";
      description = "Passes CADDY_TLS_MODE into the compose project to force fake domains or disable ACME on staging.";
    };

    fail2banIdentifier = mkOption {
      type = types.str;
      default = "impious-caddy";
      description = ''
        SYSLOG_IDENTIFIER (journald tag) that Caddy logs emit.
        Configure the compose logging driver/tag to match so fail2ban can scrape HTTP abuse.
      '';
    };

    primaryDomain = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = "Optional domain string exported as CADDY_PRIMARY_DOMAIN for host-specific overrides.";
    };

    user = mkOption {
      type = types.str;
      default = "app";
      description = "User that owns and runs docker compose.";
    };

    group = mkOption {
      type = types.str;
      default = "docker";
      description = "Primary group applied to docker compose processes.";
    };

    staticDirs = mkOption {
      type = types.attrsOf types.str;
      default = {
        site = "site";
        codex = "codex";
      };
      example = {
        site = "/opt/impious/deploy/site";
        codex = "/opt/impious/deploy/codex/public";
      };
      description = ''
        Mapping of Caddy static content targets to host directories (absolute paths or paths
        relative to services.impiousStack.deployDir). Each attribute key becomes /srv/<name>
        inside the docker compose project; the corresponding value is bind-mounted from the host.
      '';
    };

    domains = mkOption {
      type = types.listOf types.str;
      default = [ ];
      description = ''
        Additional FQDNs handed to Caddy. The list is exported to the compose
        runtime as CADDY_DOMAIN_LIST (comma-separated).
      '';
    };

    extraEnvFiles = mkOption {
      type = types.listOf types.path;
      default = [ ];
      description = "Additional EnvironmentFile entries consumed by the systemd unit (processed after the managed secret file).";
    };

    extraEnvironment = mkOption {
      type = types.attrsOf types.str;
      default = { };
      description = "Static environment variables inherited by docker compose.";
    };

    secretEnvFile = mkOption {
      type = types.path;
      default = "/var/lib/impious-stack/secrets/stack.env";
      description = "Path to the primary dotenv file that carries API keys for the compose project.";
    };

    manageSecretFile = mkOption {
      type = types.bool;
      default = true;
      description = "When true, sops-nix (if configured) writes secretEnvFile and tmpfiles keeps the parent directory locked down.";
    };

    secretSopsFile = mkOption {
      type = types.nullOr types.path;
      default = null;
      description = "Optional SOPS-encrypted source file. When set, the file materializes at secretEnvFile via sops.secrets.";
    };
  };

  staticDirEnvVars =
    listToAttrs
      (mapAttrsToList (name: dir:
        nameValuePair "IMPIOUS_STATIC_${toUpper name}" dir) resolvedStaticDirs);

  config = mkIf cfg.enable {
    assertions = [
      {
        assertion = deployDir != "";
        message = "services.impiousStack.deployDir must not be empty.";
      }
    ];

    systemd.tmpfiles.rules =
      mkAfter (map mkRule managedDirs
        ++ optional cfg.manageSecretFile (mkSecretRule secretDir));

    sops.secrets = lib.mkIf (cfg.manageSecretFile && cfg.secretSopsFile != null) {
      impious-stack-env = {
        sopsFile = cfg.secretSopsFile;
        format = "dotenv";
        owner = cfg.user;
        group = cfg.user;
        mode = "0600";
        path = secretEnvFile;
      };
    };

    systemd.services.impious-stack = {
      description = "Impious Docker stack (${cfg.environment})";
      wantedBy = [ "multi-user.target" ];
      after = [ "network-online.target" "docker.service" ];
      requires = [ "network-online.target" "docker.service" ];
      unitConfig.ConditionPathExists = deployDir;
      startLimitIntervalSec = 60;
      startLimitBurst = 3;

        environment =
          {
            COMPOSE_FILE = cfg.composeFile;
            COMPOSE_PROJECT_NAME = cfg.projectName;
            DEPLOY_ENV = cfg.environment;
            CADDY_TLS_MODE = cfg.tlsMode;
          }
          // optionalAttrs (cfg.primaryDomain != null) {
            CADDY_PRIMARY_DOMAIN = cfg.primaryDomain;
          }
          // optionalAttrs (cfg.domains != [ ]) {
            CADDY_DOMAIN_LIST = concatStringsSep "," cfg.domains;
          }
          // staticDirEnvVars
          // cfg.extraEnvironment;

      serviceConfig =
        {
          Type = "oneshot";
          RemainAfterExit = true;
          User = cfg.user;
          Group = cfg.group;
          WorkingDirectory = deployDir;
          ExecStart = "${composeBin} compose up -d --force-recreate --remove-orphans";
          ExecReload = "${composeBin} compose up -d --force-recreate --remove-orphans";
          ExecStop = "${composeBin} compose down";
          Restart = "on-failure";
          RestartSec = 10;
          TimeoutStopSec = 300;
          KillMode = "mixed";
          StandardOutput = "journal";
          StandardError = "journal";
          UMask = "0027";
          AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
          CapabilityBoundingSet = [
            "CAP_NET_BIND_SERVICE"
            "CAP_CHOWN"
            "CAP_SETGID"
            "CAP_SETUID"
            "CAP_KILL"
          ];
          NoNewPrivileges = true;
          RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
          PrivateTmp = true;
        }
        // optionalAttrs (envFiles != [ ]) {
          EnvironmentFile = envFiles;
        };
    };
  };
}
