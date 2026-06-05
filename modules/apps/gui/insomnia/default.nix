# Insomnia API Client Module
#
# Uses local package override from ./build/default.nix
# This allows running the latest version before nixpkgs PR is merged
#
# Release URL: https://github.com/Kong/insomnia/releases
# Version managed in settings/versions.nix
# Nixpkgs version: 11.6.0 (as of 2026-01-14)
# Pending PR: https://github.com/NixOS/nixpkgs/pull/480124

{
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.gui.insomnia;
  insomniaPackage = pkgs.callPackage ./build { inherit versions; };
  # Side-by-side v13 beta: distinct binary (insomnia-beta) with an isolated
  # data dir (~/.config/insomnia-beta) so its v13 DB migration cannot touch the
  # stable package's ~/.config/Insomnia. See ./build/default.nix.
  insomniaBetaPackage = pkgs.callPackage ./build {
    inherit versions;
    versionKey = "insomnia-beta";
    pname = "insomnia-beta";
    desktopName = "Insomnia 13 Beta";
    configDir = "insomnia-beta";
  };
in
{
  options = {
    apps.gui.insomnia.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Insomnia API Client (using local package override).";
    };

    apps.gui.insomnia.beta.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable the Insomnia v13 beta alongside the stable package. Installs an
        `insomnia-beta` binary with an isolated data dir
        (~/.config/insomnia-beta) so it cannot migrate the stable package's
        data. Independent of `apps.gui.insomnia.enable`.
      '';
    };
  };

  config = lib.mkMerge [
    (lib.mkIf cfg.enable {
      environment.systemPackages = [
        # Using locally overridden package for latest version
        # See ./build/default.nix for version details
        insomniaPackage
      ];
    })
    (lib.mkIf cfg.beta.enable {
      environment.systemPackages = [ insomniaBetaPackage ];
    })
  ];
}
