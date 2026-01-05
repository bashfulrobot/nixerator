{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.fish;
  username = globals.user.name;
in
{
  options = {
    apps.cli.fish.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable fish shell via home-manager.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Enable fish at system level (required for user shell)
    programs.fish.enable = true;

    # Home Manager user configuration
    home-manager.users.${username} = {

      programs.fish = {
        enable = true;

        # Fish shell configuration
        shellInit = ''
          # Disable greeting
          set fish_greeting
        '';

        # Shell aliases
        shellAliases = {
          nix-system-info = "nix-shell -p nix-info --run \"nix-info -m\"";
        };
      };

    };

  };
}
