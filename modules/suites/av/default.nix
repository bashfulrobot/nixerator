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
      # affinity: removed
      budslink.enable = true;
      cameractrls.enable = true;
      comics.enable = true;
      # Jellyfin direct-play via mpv. Replaces the native jellyfin-desktop
      # package (nixpkgs pins a broken tagless pre-release; its mpv renderer
      # fails on Wayland/AMD -- `vo/libmpv: No render context set`).
      jellyfin-mpv-shim.enable = true;
    };

    apps.cli = {
      spotify.enable = true;
    };

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
