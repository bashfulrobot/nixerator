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
    apps.cli.lswt.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable lswt - List Wayland toplevels.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ lswt ];
  };
}
