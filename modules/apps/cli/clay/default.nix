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
  cfg = config.apps.cli.clay;
  clay = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.clay = {
    enable = lib.mkEnableOption "Clay web UI for Claude Code";

    port = lib.mkOption {
      type = lib.types.port;
      default = 2633;
      description = "Port for the Clay server.";
    };

    service.enable = lib.mkEnableOption "Clay persistent server (systemd user service)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        networking.firewall.allowedTCPPorts = [ cfg.port ];

        home-manager.users.${globals.user.name} = {
          home.packages = [
            clay
            pkgs.mkcert
          ];
        };
      }

      (lib.mkIf cfg.service.enable {
        home-manager.users.${globals.user.name} = {
          systemd.user.services.clay-server = {
            Unit = {
              Description = "Clay web UI for Claude Code";
              After = [ "network.target" ];
            };
            Service = {
              Type = "forking";
              ExecStart =
                "${clay}/bin/clay-server --headless --yes --no-update -p ${toString cfg.port}"
                + lib.optionalString (secrets.clay.pin or null != null) " --pin ${secrets.clay.pin}";
              ExecStop = "${clay}/bin/clay-server --shutdown";
              Restart = "on-failure";
              RestartSec = 10;
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
