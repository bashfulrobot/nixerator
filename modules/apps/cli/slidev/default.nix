{
  lib,
  config,
  pkgs,
  globals,
  ...
}:

let
  cfg = config.apps.cli.slidev;
in
{
  options = {
    apps.cli.slidev.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Slidev presentation slides for developers.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ pkgs.slidev-cli ];
    };
  };
}
