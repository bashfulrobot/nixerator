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
    apps.cli.slidev.enable = lib.mkEnableOption "Slidev presentation slides for developers";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ pkgs.slidev-cli ];
    };
  };
}
