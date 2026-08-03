{
  config,
  lib,
  pkgs,
  versions,
  ...
}:

let
  cfg = config.apps.cli.gws;
  gws = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.gws.enable = lib.mkEnableOption "gws - Google Workspace CLI for Drive, Gmail, Calendar, Sheets, Docs, Chat, Admin, and more";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      gws
    ];
  };
}
