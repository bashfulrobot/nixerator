{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.suites.av;
in
{
  options = {
    suites.av.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable audio/visual suite with creative applications and media players.";
    };
  };

  config = lib.mkIf cfg.enable {
    apps.gui = {
      affinity.enable = true;
      cameractrls.enable = true;
      comics.enable = true;
    };

    apps.cli = {
      spotify.enable = true;
    };

    services.flatpak.packages = [
      "org.jellyfin.JellyfinDesktop"
    ];

    environment.systemPackages = with pkgs; [
      inkscape # vector graphics editor
      losslesscut-bin # lossless video/audio cutting and merging
      vlc # media player
      mpv # video player
      v4l-utils # webcam and video device utilities
      go-chromecast # CLI for casting to Chromecast devices
    ];
  };
}
