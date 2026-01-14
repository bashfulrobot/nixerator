# Insomnia API Client Module
#
# Uses local package override from ../../packages/insomnia
# This allows running the latest version before nixpkgs PR is merged
#
# TODO: Version bump reminder - Check for new releases monthly
# Release URL: https://github.com/Kong/insomnia/releases
# Current local version: 12.2.0 (see ../../packages/insomnia/default.nix)
# Nixpkgs version: 11.6.0 (as of 2026-01-14)
# Pending PR: https://github.com/NixOS/nixpkgs/pull/480124

{ lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.insomnia;

in
{
  options = {
    apps.gui.insomnia.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Insomnia API Client (using local package override).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Using locally overridden package for latest version
      # See ../../packages/insomnia/default.nix for version details
      insomnia
    ];
  };
}
