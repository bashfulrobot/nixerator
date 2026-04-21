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
  clawide = pkgs.callPackage ./build { inherit versions; };
  inherit (pkgs.llm-agents) claude-code;
in
{
  options.apps.cli.claw-ide = {
    enable = lib.mkEnableOption "ClawIDE web-based IDE for Claude Code";

    port = lib.mkOption {
      type = lib.types.port;
      default = 9800;
      description = "Port for the ClawIDE web server.";
    };

    host = lib.mkOption {
      type = lib.types.str;
      default = "0.0.0.0";
      description = "Bind address for the ClawIDE web server.";
    };

    projectsDir = lib.mkOption {
      type = lib.types.str;
      default = globals.user.homeDirectory;
      description = "Root directory ClawIDE browses for projects.";
    };

    service.enable = lib.mkEnableOption "ClawIDE persistent server (systemd user service)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        networking.firewall.allowedTCPPorts = [ cfg.port ];

        home-manager.users.${globals.user.name} = {
          home.packages = [ clawide ];
        };
      }

      (lib.mkIf cfg.service.enable {
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
                "-host ${cfg.host}"
                "-port ${toString cfg.port}"
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
