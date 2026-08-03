{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.lswt;
  lswt = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.lswt.enable = lib.mkEnableOption "lswt - List Wayland toplevels";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ lswt ];
  };
}
