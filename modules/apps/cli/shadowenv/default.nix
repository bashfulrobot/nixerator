{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.shadowenv;
  username = globals.user.name;
in
{
  options = {
    apps.cli.shadowenv.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable shadowenv for directory-based environment switching.";
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [ pkgs.shadowenv ];

    home-manager.users.${username} = {

      programs.fish = {
        interactiveShellInit = ''
          shadowenv init fish | source
        '';
      };

    };

  };
}
