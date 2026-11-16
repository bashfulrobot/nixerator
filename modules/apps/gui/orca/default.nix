# Orca Module
#
# Uses local package from ./build/default.nix
# Agent development environment (https://orca.dev), AppImage wrapped with
# appimageTools. Version managed in settings/versions.nix.
#
# TODO: Version bump reminder - the AppImage cannot self-update from the store.
# Release URL: https://github.com/stablyai/orca/releases

{
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.gui.orca;
  orcaPackage = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.gui.orca.enable = lib.mkEnableOption "Orca agent development environment";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ orcaPackage ];
  };
}
