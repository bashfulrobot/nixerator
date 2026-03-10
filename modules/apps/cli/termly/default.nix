{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.termly;
  termly = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.termly.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Termly CLI for mobile AI session mirroring.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ termly ];
    };
  };
}
