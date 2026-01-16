# Helium Browser Module
#
# Uses local package from ../../packages/helium
# Chromium-based privacy-focused browser (beta)
#
# TODO: Version bump reminder - Check for new releases monthly
# Release URL: https://github.com/imputnet/helium-linux/releases
# Current local version: 0.8.1 (see ../../packages/helium/default.nix)
# Note: Helium is currently in beta

{ lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.helium;

in
{
  options = {
    apps.gui.helium.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Helium browser (privacy-focused Chromium-based browser).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Using locally packaged Helium browser
      # See ../../packages/helium/default.nix for version details
      helium
    ];
  };
}
