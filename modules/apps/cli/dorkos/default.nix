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
  cfg = config.apps.cli.dorkos;
  dorkos = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.dorkos = {
    enable = lib.mkEnableOption "DorkOS agent coordination server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 4242;
      description = ''
        Port for the DorkOS Express server. DorkOS binds to loopback only;
        LAN/Tailscale access requires a reverse proxy or the built-in ngrok tunnel.
      '';
    };

    service.enable = lib.mkEnableOption "DorkOS persistent server (systemd user service)";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ dorkos ];

      systemd.user.services = lib.mkIf cfg.service.enable {
        dorkos = {
          Unit = {
            Description = "DorkOS agent coordination server";
            After = [ "network.target" ];
          };
          Service = {
            ExecStart = lib.concatStringsSep " " [
              "${dorkos}/bin/dorkos"
              "--port ${toString cfg.port}"
              "--no-open"
            ];
            Environment = lib.optionals (secrets ? anthropic && secrets.anthropic ? apiKey) [
              "ANTHROPIC_API_KEY=${secrets.anthropic.apiKey}"
            ];
            Restart = "on-failure";
            RestartSec = 5;
          };
          Install = {
            WantedBy = [ "default.target" ];
          };
        };
      };
    };
  };
}
