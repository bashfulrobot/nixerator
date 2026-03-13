{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.openspec;
  openspec = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.openspec.enable = lib.mkEnableOption "OpenSpec spec-driven development CLI";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ openspec ];
    };
  };
}
