{
  globals,
  lib,
  config,
  pkgs,
  ...
}:

let
  cfg = config.apps.cli.docker;
in
{
  options = {
    apps.cli.docker.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Docker CLI and container runtime.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Add user to docker group
    users.users."${globals.user.name}".extraGroups = [ "docker" ];

    # Enable Docker virtualization
    virtualisation = {
      docker = {
        enable = true;
        autoPrune = {
          enable = true;
          dates = "weekly";
        };
        daemon.settings = {
          log-driver = "json-file";
          log-opts = {
            max-size = "10m";
            max-file = "3";
          };
        };
      };
    };

    # Grant user direct socket access so systemd user services can reach Docker
    systemd.services.docker.postStart = ''
      ${pkgs.acl}/bin/setfacl -m u:${globals.user.name}:rw /var/run/docker.sock
    '';

    # Home Manager configuration for docker aliases
    home-manager.users.${globals.user.name} = {
      programs.fish = {
        shellAliases = {
          d = "docker";
          dc = "docker compose";
          dps = "docker ps";
          di = "docker images";
          dexe = "docker exec -it";
        };
      };
    };
  };
}
