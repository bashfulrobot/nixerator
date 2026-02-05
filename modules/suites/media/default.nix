{ lib, pkgs, config, ... }:

let
  cfg = config.suites.media;
in
{
  options = {
    suites.media.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable media suite with music and video players.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Music and media apps
    apps.cli = {
      spotify.enable = true;
    };

    # Additional media packages
    environment.systemPackages = with pkgs; [
      vlc        # media player
      mpv        # video player
      v4l-utils  # webcam and video device utilities
    ];
  };
}
