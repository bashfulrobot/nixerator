{
  globals,
  lib,
  config,
  ...
}:

let
  cfg = config.apps.cli.zoxide;
  username = globals.user.name;
in
{
  options = {
    apps.cli.zoxide.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable zoxide for smarter directory navigation.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Home Manager user configuration
    home-manager.users.${username} = {

      programs.zoxide = {
        enable = true;
        enableFishIntegration = true;
        options = [
          # Replace cd.
          "--cmd cd"
        ];
      };

    };

  };
}
