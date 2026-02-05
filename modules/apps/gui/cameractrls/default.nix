{ lib, config, ... }:

let
  cfg = config.apps.gui.cameractrls;
in
{
  options = {
    apps.gui.cameractrls.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable cameractrls - Camera controls for Linux.";
    };
  };

  config = lib.mkIf cfg.enable {
    services.flatpak.packages = [
      "hu.irl.cameractrls"
    ];
  };
}
