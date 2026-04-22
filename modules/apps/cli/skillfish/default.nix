{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.skillfish;
  skillfish = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.skillfish = {
    enable = lib.mkEnableOption "Skillfish -- skill manager for AI coding agents";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ skillfish ];
    };
  };
}
