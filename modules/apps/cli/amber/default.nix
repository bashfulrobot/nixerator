{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.amber;
  amber = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.amber.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable amber - a code search and replace tool providing ambs (search) and ambr (replace).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ amber ];
  };
}
