{ lib, config, ... }:

let
  cfg = config.apps.gui.cauldron;
in
{
  options = {
    apps.gui.cauldron.enable = lib.mkEnableOption "Cauldron - a GTK desktop client for Instapaper";
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.packages = [
      "it.dottorblaster.cauldron"
    ];
  };
}
