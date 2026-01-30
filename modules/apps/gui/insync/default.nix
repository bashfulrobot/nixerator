{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

# Insync Module
# Google Drive sync client with Nautilus integration

let
  cfg = config.apps.gui.insync;
  username = globals.user.name;

  # Desktop entry with --no-daemon flag for proper operation
  insyncDesktopEntry = ''
    [Desktop Entry]
    Version=1.0
    Type=Application
    Name=Insync
    GenericName=Insync
    Comment=Google Drive sync client
    Icon=insync
    Categories=Network;
    Exec=insync start --no-daemon
    TryExec=insync
    Terminal=false
  '';
in
{
  options.apps.gui.insync = {
    enable = lib.mkEnableOption "Insync Google Drive sync client";

    nautilusIntegration = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Enable Nautilus file manager integration for Insync.";
    };

    autostart = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Start Insync automatically on login.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs;
      [ insync ]
      ++ lib.optionals cfg.nautilusIntegration [ insync-nautilus ];

    home-manager.users.${username} = {
      # Override the default desktop entry to use --no-daemon
      home.file.".local/share/applications/insync.desktop".text = insyncDesktopEntry;

      # Autostart entry
      home.file.".config/autostart/insync.desktop" = lib.mkIf cfg.autostart {
        text = insyncDesktopEntry;
      };
    };
  };
}
