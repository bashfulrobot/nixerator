{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.graymatter;
  graymatter = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.graymatter = {
    enable = lib.mkEnableOption "GrayMatter - persistent memory for AI agents";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.packages = [ graymatter ];
    };
  };
}
