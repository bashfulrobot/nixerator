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
  caddyCfg = config.system.caddy;
  clay = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.clay = {
    enable = lib.mkEnableOption "Clay web UI for Claude Code";

    port = lib.mkOption {
      type = lib.types.port;
      default = 3131;
      description = "External HTTPS port (served by Caddy) for Clay on the tailnet.";
    };

    internalPort = lib.mkOption {
      type = lib.types.port;
      default = 4131;
      description = "Loopback port where Clay itself listens (proxied by Caddy).";
    };

    service.enable = lib.mkEnableOption "Clay persistent server (systemd user service + Caddy vhost)";

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
        home-manager.users.${globals.user.name} = {
          home.packages = [
            clay
            pkgs.mkcert
          ];
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
                  ${pkgs.jq}/bin/jq '.port = ${toString cfg.internalPort}' "$cfg" > "$cfg.tmp" && mv "$cfg.tmp" "$cfg"
                fi
              '';
              ExecStart =
                let
                  args =
                    "--headless --yes --no-update --no-https --host 127.0.0.1 -p ${toString cfg.internalPort}"
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
