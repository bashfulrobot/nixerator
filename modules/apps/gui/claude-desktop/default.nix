# Claude desktop app (Electron) — Chat, Cowork, and Claude Code on Linux.
#
# Uses local package from ./build/default.nix (nixpkgs has no derivation).
# Version managed in settings/versions.nix (gui.claude-desktop).
# Docs / updates: https://code.claude.com/docs/en/desktop-linux

{
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.gui.claude-desktop;
  claudeDesktopPackage = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.gui.claude-desktop.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the Claude desktop app (Chat, Cowork, and Claude Code).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      claudeDesktopPackage
    ];
  };
}
