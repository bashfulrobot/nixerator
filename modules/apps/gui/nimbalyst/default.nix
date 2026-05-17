# Nimbalyst — visual editor and session manager for Claude Code & Codex.
#
# Uses local package from ./build/default.nix
# Version managed in settings/versions.nix
# Release URL: https://github.com/Nimbalyst/nimbalyst/releases

{
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.gui.nimbalyst;
  nimbalystPackage = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.gui.nimbalyst.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Nimbalyst visual editor for Claude Code & Codex.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      nimbalystPackage
    ];
  };
}
