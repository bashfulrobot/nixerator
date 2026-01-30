{
  lib,
  pkgs,
  config,
  ...
}:

# Insync Module
# Google Drive sync client with Nautilus integration

let
  cfg = config.apps.gui.insync;
in
{
  options.apps.gui.insync = {
    enable = lib.mkEnableOption "Insync Google Drive sync client";

    nautilusIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Nautilus file manager integration for Insync.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      [ insync ]
      ++ lib.optionals cfg.nautilusIntegration [ insync-nautilus ];

    # Autostart insync via hyprflake's autostart.d pattern
    hyprflake.desktop.autostartD.execOnce = {
      "50-insync" = "insync start --no-daemon";
    };
  };
}
