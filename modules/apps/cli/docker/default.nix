{ globals, lib, config, ... }:

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
      };
    };

    # Home Manager configuration for docker aliases
    home-manager.users.${globals.user.name} = {
      programs.fish = {
        shellAliases = {
          d = "docker";
          dc = "docker compose";
          dps = "docker ps";
          di = "docker images";
          dex = "docker exec -it";
          dlogs = "docker logs -f";
        };
      };
    };
  };
}
