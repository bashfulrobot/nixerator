{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.zellij;
  caddyCfg = config.system.caddy;
in
{
  options.apps.cli.zellij = {
    enable = lib.mkEnableOption "Zellij terminal multiplexer";

    defaultShell = lib.mkOption {
      type = lib.types.str;
      default = globals.preferences.shell;
      description = "Login shell zellij spawns inside new panes (default: globals.preferences.shell).";
    };

    tsnetNode = lib.mkOption {
      type = lib.types.str;
      default = "zellij";
      description = "Tailnet node name Caddy joins as for zellij web (URL: https://<node>.<tailnetDomain>/).";
    };

    internalPort = lib.mkOption {
      type = lib.types.port;
      default = 8082;
      description = "Loopback port where zellij web listens (proxied by Caddy via tsnet).";
    };

    service.enable = lib.mkEnableOption "zellij web persistent server (systemd user service + Caddy tsnet vhost)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home-manager.users.${globals.user.name} = {
          programs.zellij = {
            enable = true;
            package = pkgs.zellij;
            settings = {
              default_shell = cfg.defaultShell;
            };
          };
        };
      }

      (lib.mkIf cfg.service.enable {
        system.caddy = {
          enable = true;
          tsnetNodes = [ cfg.tsnetNode ];
        };

        services.caddy.virtualHosts."https://${cfg.tsnetNode}.${caddyCfg.tailnetDomain}" = {
          extraConfig = ''
            bind tailscale/${cfg.tsnetNode}
            reverse_proxy 127.0.0.1:${toString cfg.internalPort}
          '';
        };

        home-manager.users.${globals.user.name} = {
          systemd.user.services.zellij-web = {
            Unit = {
              Description = "Zellij web client (browser-accessible terminal multiplexer)";
              After = [ "network.target" ];
            };
            Service = {
              ExecStart = lib.concatStringsSep " " [
                "${pkgs.zellij}/bin/zellij"
                "web"
                "--start"
                "--ip 127.0.0.1"
                "--port ${toString cfg.internalPort}"
              ];
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
