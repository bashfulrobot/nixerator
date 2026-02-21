{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.yepanywhere;
  yepanywhereCli = pkgs.callPackage ./build { };
in
{
  options = {
    apps.cli.yepanywhere = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable yepanywhere CLI.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ yepanywhereCli ];
  };
}
