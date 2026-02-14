{ lib, config, ... }:

let
  cfg = config.suites.av;
in
{
  options = {
    suites.av.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable audio/visual suite with creative applications.";
    };
  };

  config = lib.mkIf cfg.enable {
    apps.gui = {
      affinity.enable = true;
    };

    services.flatpak.packages = [
      "org.jellyfin.JellyfinDesktop"
    ];
  };
}
