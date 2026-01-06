{ globals, pkgs, lib, config, ... }:

let
  cfg = config.apps.cli.docker;
  username = globals.user.name;
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
    users.users."${username}".extraGroups = [ "docker" ];

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
  };
}
