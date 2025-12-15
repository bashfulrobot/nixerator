{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.signal;
  username = globals.user.name;

  # Override Signal desktop to add password store flag
  customSignal = pkgs.signal-desktop.overrideAttrs (oldAttrs: rec {
    desktopItems = map (item: item.override (d: {
      exec = "${pkgs.signal-desktop}/bin/signal-desktop --password-store=\"gnome-libsecret\" --no-sandbox %U";
    })) oldAttrs.desktopItems;

    installPhase = builtins.replaceStrings
      (map (item: "${item}") oldAttrs.desktopItems)
      (map (item: "${item}") desktopItems)
      oldAttrs.installPhase;
  });

in
{
  options = {
    apps.gui.signal = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Signal desktop messaging application.";
      };
      forceGnomeLibsecret = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Force Signal to use GNOME libsecret for password storage.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Install Signal - either custom or regular based on forceGnomeLibsecret option
    environment.systemPackages = [
      (if cfg.forceGnomeLibsecret then customSignal else pkgs.signal-desktop)
    ];
  };
}
