{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.claw-ide;
  caddyCfg = config.system.caddy;
  clawide = pkgs.callPackage ./build { inherit versions; };
  inherit (pkgs.llm-agents) claude-code;
in
{
  options.apps.cli.claw-ide = {
    enable = lib.mkEnableOption "ClawIDE web-based IDE for Claude Code";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3133;
      description = "External HTTPS port (served by Caddy) for ClawIDE on the tailnet.";
    };

    internalPort = lib.mkOption {
      type = lib.types.port;
      default = 4133;
      description = "Loopback port where ClawIDE itself listens (proxied by Caddy).";
    };

    projectsDir = lib.mkOption {
      type = lib.types.str;
      default = globals.user.homeDirectory;
      description = "Root directory ClawIDE browses for projects.";
    };

    service.enable = lib.mkEnableOption "ClawIDE persistent server (systemd user service + Caddy vhost)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home-manager.users.${globals.user.name} = {
          home.packages = [ clawide ];
        };
      }

      (lib.mkIf cfg.service.enable {
        system.caddy = {
          enable = true;
          openFirewall = [ cfg.port ];
        };

        services.caddy.virtualHosts."${caddyCfg.tailnetHostname}:${toString cfg.port}" = {
          extraConfig = ''
            tls ${caddyCfg.certFile} ${caddyCfg.keyFile}
            reverse_proxy 127.0.0.1:${toString cfg.internalPort}
          '';
        };

        home-manager.users.${globals.user.name} = {
          systemd.user.services.claw-ide = {
            Unit = {
              Description = "ClawIDE web-based IDE for Claude Code";
              After = [ "network.target" ];
            };
            Service = {
              Environment = [
                "PATH=${
                  lib.makeBinPath [
                    pkgs.tmux
                    pkgs.git
                    pkgs.coreutils
                  ]
                }"
              ];
              ExecStart = lib.concatStringsSep " " [
                "${clawide}/bin/clawide"
                "-host 127.0.0.1"
                "-port ${toString cfg.internalPort}"
                "-projects-dir ${cfg.projectsDir}"
                "-agent-command ${claude-code}/bin/claude"
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
