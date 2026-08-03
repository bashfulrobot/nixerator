{ lib, config, ... }:

let
  cfg = config.apps.gui.budslink;
in
{
  options = {
    apps.gui.budslink.enable = lib.mkEnableOption "BudsLink - desktop control for Bluetooth earbuds (AirPods, Galaxy Buds, etc.)";
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.packages = [
      "io.github.maniacx.BudsLink"
    ];
  };
}
