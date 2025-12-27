{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.superfile;
  username = globals.user.name;
in
{
  options = {
    apps.cli.superfile.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable superfile terminal file manager.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      programs.superfile = {
        enable = true;
      };
    };
  };
}
