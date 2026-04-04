{
  lib,
  pkgs,
  config,
  globals,
  secrets,
  versions,
  ...
}:

let
  cfg = config.server.claudito;
  claudito = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    server.claudito = {
      enable = lib.mkEnableOption "Claudito agent dashboard";

      port = lib.mkOption {
        type = lib.types.port;
        default = 3113;
        description = "Port for the claudito web server.";
      };

      host = lib.mkOption {
        type = lib.types.str;
        default = "0.0.0.0";
        description = "Host/interface to bind to.";
      };

      maxAgents = lib.mkOption {
        type = lib.types.int;
        default = 3;
        description = "Maximum concurrent Claude agents.";
      };

      devMode = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable experimental features (Git tab, etc).";
      };

      projectPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = "Additional project discovery paths (colon-separated in env).";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    home-manager.users.${globals.user.name} = {
      home.packages = [ claudito ];

      systemd.user.services.claudito = {
        Unit = {
          Description = "Claudito - Claude Code Agent Dashboard";
          After = [ "network.target" ];
        };

        Service = {
          Type = "simple";
          ExecStart = "${claudito}/bin/claudito";
          Restart = "on-failure";
          RestartSec = 10;
          Environment = [
            "PORT=${toString cfg.port}"
            "HOST=${cfg.host}"
            "MAX_CONCURRENT_AGENTS=${toString cfg.maxAgents}"
          ]
          ++ lib.optionals (secrets.claudito or null != null) [
            "CLAUDITO_USERNAME=${secrets.claudito.username}"
            "CLAUDITO_PASSWORD=${secrets.claudito.password}"
          ]
          ++ lib.optional cfg.devMode "CLAUDITO_DEV_MODE=1"
          ++ lib.optional (
            cfg.projectPaths != [ ]
          ) "CLAUDITO_PROJECT_PATHS=${lib.concatStringsSep ":" cfg.projectPaths}";
        };

        Install = {
          WantedBy = [ "default.target" ];
        };
      };
    };
  };
}
