{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.gui.chromium;
  username = globals.user.name;
in
{
  options = {
    apps.gui.chromium.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Chromium web browser.";
    };
  };

  config = lib.mkIf cfg.enable {

    # Home Manager user configuration
    home-manager.users.${username} = {

      programs.chromium = {
        enable = true;

        # Extensions can be added here
        # extensions = [
        #   { id = "cjpalhdlnbpafiamejdnhcphjbkeiagm"; } # uBlock Origin
        # ];

        # Command line arguments
        commandLineArgs = [
          # Enable Wayland support
          "--enable-features=UseOzonePlatform"
          "--ozone-platform=wayland"

          # Hardware acceleration
          "--enable-features=VaapiVideoDecoder"
          "--enable-gpu-rasterization"

          # Additional flags
          "--force-dark-mode"
        ];
      };

    };

  };
}
