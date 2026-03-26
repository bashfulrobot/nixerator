{
  globals,
  lib,
  config,
  ...
}:

let
  cfg = config.apps.cli.direnv;
in
{
  options = {
    apps.cli.direnv.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable direnv with nix-direnv for automatic directory-based environments.";
    };
  };

  config = lib.mkIf cfg.enable {

    home-manager.users.${globals.user.name} = {

      programs.direnv = {
        enable = true;
        nix-direnv.enable = true;
        config = {
          global = {
            hide_env_diff = true;
          };
        };
      };

    };

  };
}
