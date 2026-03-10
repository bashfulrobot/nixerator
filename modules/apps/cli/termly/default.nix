{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.termly;
  termly = pkgs.callPackage ./build { inherit versions; };
  termlyTrigger = pkgs.callPackage ./build/trigger.nix { };

  directoriesFile = pkgs.writeText "termly-directories.json" (builtins.toJSON cfg.remote.directories);

  termlyWrapper = pkgs.writeShellScript "termly-wrapper" ''
    ENV_FILE="/tmp/termly-session.env"
    if [ -f "$ENV_FILE" ]; then
      . "$ENV_FILE"
    fi
    cd "''${TERMLY_DIR:-.}" || exit 1
    exec ${termly}/bin/termly
  '';
in
{
  options = {
    apps.cli.termly = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Termly CLI for mobile AI session mirroring.";
      };

      remote = {
        enable = lib.mkEnableOption "remote termly trigger";

        port = lib.mkOption {
          type = lib.types.port;
          default = 9735;
          description = "Port for the termly trigger HTTP server.";
        };

        directories = lib.mkOption {
          type = lib.types.listOf lib.types.str;
          default = [ ];
          example = [
            "/home/user/dev/project1"
            "/home/user/dev/project2"
          ];
          description = "Project directories available for remote termly sessions.";
        };
      };
    };
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home-manager.users.${globals.user.name} = {
          home.packages = [ termly ];
        };
      }

      (lib.mkIf cfg.remote.enable {
        networking.firewall.allowedTCPPorts = [ cfg.remote.port ];

        home-manager.users.${globals.user.name} = {
          systemd.user.services.termly-trigger = {
            Unit = {
              Description = "Termly remote trigger HTTP server";
              After = [ "network.target" ];
            };
            Service = {
              Type = "simple";
              Environment = [
                "TERMLY_DIRECTORIES_FILE=${directoriesFile}"
                "TERMLY_ENV_FILE=/tmp/termly-session.env"
              ];
              ExecStart = "${termlyTrigger}/bin/termly-trigger ${toString cfg.remote.port}";
              Restart = "on-failure";
              RestartSec = 5;
            };
            Install = {
              WantedBy = [ "default.target" ];
            };
          };

          systemd.user.services.termly = {
            Unit = {
              Description = "Termly mobile AI session mirror";
            };
            Service = {
              Type = "simple";
              ExecStart = toString termlyWrapper;
              Restart = "no";
            };
          };
        };
      })
    ]
  );
}
