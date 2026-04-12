{
  lib,
  pkgs,
  config,
  globals,
  secrets,
  ...
}:

let
  cfg = config.apps.cli.ccpocket;
in
{
  options.apps.cli.ccpocket = {
    enable = lib.mkEnableOption "CC Pocket bridge for remote Claude Code management";

    port = lib.mkOption {
      type = lib.types.port;
      default = 8765;
      description = "WebSocket port for the CC Pocket bridge server.";
    };

    service.enable = lib.mkEnableOption "CC Pocket bridge persistent systemd user service";

    allowedDirs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Project directories the bridge is allowed to access (comma-joined for BRIDGE_ALLOWED_DIRS).";
      example = [
        "~/git/nixerator"
        "~/git/other-project"
      ];
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        networking.firewall.allowedTCPPorts = [ cfg.port ];

        home-manager.users.${globals.user.name} = {
          home.packages = [ pkgs.nodejs_22 ];
        };
      }

      (lib.mkIf cfg.service.enable {
        home-manager.users.${globals.user.name} = {
          systemd.user.services.ccpocket-bridge = {
            Unit = {
              Description = "CC Pocket bridge server for remote Claude Code management";
              After = [ "network.target" ];
            };
            Service = {
              Type = "simple";
              Environment =
                let
                  base = [
                    "BRIDGE_PORT=${toString cfg.port}"
                    "BRIDGE_HOST=0.0.0.0"
                    "PATH=${lib.makeBinPath [ pkgs.nodejs_22 ]}:/usr/bin:/bin"
                  ];
                  apiKey = lib.optionals (secrets.ccpocket.api_key or null != null) [
                    "BRIDGE_API_KEY=${secrets.ccpocket.api_key}"
                  ];
                  anthropicKey = lib.optionals (secrets.anthropic.api_key or null != null) [
                    "ANTHROPIC_API_KEY=${secrets.anthropic.api_key}"
                  ];
                  allowedDirs = lib.optionals (cfg.allowedDirs != [ ]) [
                    "BRIDGE_ALLOWED_DIRS=${lib.concatStringsSep "," cfg.allowedDirs}"
                  ];
                in
                base ++ apiKey ++ anthropicKey ++ allowedDirs;
              ExecStart = "${pkgs.nodejs_22}/bin/npx @ccpocket/bridge@latest";
              Restart = "on-failure";
              RestartSec = 5;
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
          };
        };
      })
    ]
  );
}
