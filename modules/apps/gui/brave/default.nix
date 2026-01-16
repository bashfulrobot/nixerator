{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.brave;
  username = globals.user.name;
in
{
  options = {
    apps.gui.brave.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Brave web browser.";
    };
  };

  config = lib.mkIf cfg.enable {

    # System packages
    environment.systemPackages = with pkgs; [
      brave
    ];

    # Home Manager user configuration
    home-manager.users.${username} = {

      # Wayland flags for Brave
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
          ".config/brave-flags.conf".text = waylandFlags;
        };

    };

  };
}
