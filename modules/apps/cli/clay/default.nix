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

    service.enable = lib.mkEnableOption "Clay persistent server (Hyprland exec-once)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        networking.firewall.allowedTCPPorts = [
          cfg.port
          (cfg.port + 1) # clay onboarding/PIN auth port
        ];

        home-manager.users.${globals.user.name} = {
          home.packages = [
            clay
            pkgs.mkcert
          ];
        };
      }

      (lib.mkIf cfg.service.enable {
        home-manager.users.${globals.user.name} = {
          xdg.configFile."hypr/conf.d/clay-server.conf".text =
            let
              args =
                "--headless --yes --no-update -p ${toString cfg.port}"
                + lib.optionalString (secrets.clay.pin or null != null) " --pin ${secrets.clay.pin}";
            in
            "exec-once = ${clay}/bin/clay-server ${args}";
        };
      })
    ]
  );
}
