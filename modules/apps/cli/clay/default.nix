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
      default = 3131;
      description = "Port for the Clay server.";
    };

    service.enable = lib.mkEnableOption "Clay persistent server (systemd user service)";

    projects = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = "Project directories to register with Clay on startup.";
      example = [
        "~/git/nixerator"
        "~/git/other-project"
      ];
    };
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
          systemd.user.services.clay = {
            Unit = {
              Description = "Clay web UI for Claude Code";
              After = [ "network.target" ];
            };
            Service = {
              Type = "forking";
              ExecStartPre = pkgs.writeShellScript "clay-set-port" ''
                cfg="$HOME/.clay/daemon.json"
                if [ -f "$cfg" ]; then
                  ${pkgs.jq}/bin/jq '.port = ${toString cfg.port}' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
                fi
              '';
              ExecStart =
                let
                  args =
                    "--headless --yes --no-update -p ${toString cfg.port}"
                    + lib.optionalString (secrets.clay.pin or null != null) " --pin ${secrets.clay.pin}";
                in
                "${clay}/bin/clay-server ${args}";
              ExecStartPost = lib.optionals (cfg.projects != [ ]) [
                (pkgs.writeShellScript "clay-add-projects" ''
                  sleep 3
                  ${lib.concatMapStringsSep "\n" (dir: "${clay}/bin/clay-server --add ${dir}") cfg.projects}
                '')
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
