{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.clay;
  clay = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.clay.enable = lib.mkEnableOption "Clay web UI for Claude Code";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [
        clay
        pkgs.mkcert
      ];
    };
  };
}
