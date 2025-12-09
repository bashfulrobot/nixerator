{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.google-chrome;
  username = globals.user.name;
in
{
  options = {
    apps.gui.google-chrome.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Google Chrome web browser.";
    };
  };

  config = lib.mkIf cfg.enable {

    # System packages
    environment.systemPackages = with pkgs; [
      google-chrome
    ];

    # Home Manager user configuration
    home-manager.users.${username} = {

      # Wayland flags for Chrome
      home.file =
        let
          waylandFlags = ''
            --enable-features=UseOzonePlatform
            --ozone-platform=wayland
            --enable-features=WaylandWindowDecorations
            --ozone-platform-hint=wayland
            --gtk-version=4
            --enable-features=VaapiVideoDecoder
            --enable-gpu-rasterization
          '';
        in
        {
          ".config/chrome-flags.conf".text = waylandFlags;
        };

    };

  };
}
