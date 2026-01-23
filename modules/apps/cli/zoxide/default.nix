{
  globals,
  lib,
  config,
  pkgs,
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
        # Disabled - using zoxide.fish plugin for enhanced tab completion
        enableFishIntegration = false;
      };

      # zoxide.fish provides enhanced tab completion that completes directories
      # first, then falls back to zoxide queries. Also aliases cd to z by default.
      # https://github.com/icezyclon/zoxide.fish
      programs.fish.plugins = [
        {
          name = "zoxide.fish";
          src = pkgs.fetchFromGitHub {
            owner = "icezyclon";
            repo = "zoxide.fish";
            rev = "3.0";
            hash = "sha256-OjrX0d8VjDMxiI5JlJPyu/scTs/fS/f5ehVyhAA/KDM=";
          };
        }
      ];

    };

  };
}
