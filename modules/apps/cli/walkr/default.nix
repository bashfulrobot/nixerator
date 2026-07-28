{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.walkr;
  walkr = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.walkr.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable walkr, the renderer for hand-authored topic walkthroughs (static wizard-style teaching sites).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ walkr ];
  };
}
