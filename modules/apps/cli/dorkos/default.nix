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
  caddyCfg = config.system.caddy;
  dorkos = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.dorkos = {
    enable = lib.mkEnableOption "DorkOS agent coordination server";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3134;
      description = "External HTTPS port (served by Caddy) for DorkOS on the tailnet.";
    };

    internalPort = lib.mkOption {
      type = lib.types.port;
      default = 4242;
      description = ''
        Loopback port where DorkOS itself listens (proxied by Caddy).
        DorkOS always binds to 127.0.0.1; upstream exposes no --host flag.
      '';
    };

    service.enable = lib.mkEnableOption "DorkOS persistent server (systemd user service + Caddy vhost)";
  };

  config = lib.mkIf cfg.enable (
    lib.mkMerge [
      {
        home-manager.users.${globals.user.name} = {
          home.packages = [ dorkos ];
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
            reverse_proxy [::1]:${toString cfg.internalPort}
          '';
        };

        home-manager.users.${globals.user.name} = {
          systemd.user.services.dorkos = {
            Unit = {
              Description = "DorkOS agent coordination server";
              After = [ "network.target" ];
            };
            Service = {
              ExecStart = lib.concatStringsSep " " [
                "${dorkos}/bin/dorkos"
                "--port ${toString cfg.internalPort}"
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
      })
    ]
  );
}
