# PCtrl Process Manager Module
#
# Uses local package from ../../packages/pctrl
# Rust + Tauri-based process manager with TUI and GUI interfaces
#
# TODO: Version bump reminder - Check for new releases
# Release URL: https://github.com/MohamedSherifNoureldin/PCtrl/releases
# Current local version: 1.0.0 (see ../../packages/pctrl/default.nix)

{ lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.pctrl;
in
{
  options = {
    apps.gui.pctrl.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable PCtrl process manager (Rust-based process manager with TUI and GUI).";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # Using locally packaged PCtrl
      # See ../../packages/pctrl/default.nix for version details
      pctrl
    ];
  };
}
