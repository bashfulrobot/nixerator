{ lib, config, ... }:

let
  cfg = config.apps.gui.budslink;
in
{
  options = {
    apps.gui.budslink.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable BudsLink - desktop control for Bluetooth earbuds (AirPods, Galaxy Buds, etc.).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.packages = [
      "io.github.maniacx.BudsLink"
    ];
  };
}
