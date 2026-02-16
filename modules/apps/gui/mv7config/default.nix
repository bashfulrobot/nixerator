# mv7config Module
#
# Uses local package from ../../../../packages/mv7config
# Unofficial utility for configuring Shure MV7 microphones

{ lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.mv7config;

in
{
  options = {
    apps.gui.mv7config.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable mv7config for Shure MV7 microphone configuration.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.mv7config
    ];

    # Install udev rules for MV7 access
    services.udev.packages = [
      pkgs.mv7config
    ];
  };
}
