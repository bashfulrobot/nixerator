{
  globals,
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
  options = {
    apps.gui.insync = {
      enable = lib.mkEnableOption "Insync Google Drive sync client";

      nautilusIntegration = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Nautilus file manager integration for Insync.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [ insync ] ++ lib.optionals cfg.nautilusIntegration [ insync-nautilus ];

    # Autostart insync as a systemd user service rather than a hyprland
    # `exec-once`/lua hook. A lua hook has no supervision and no ordering, so
    # insync could launch before DankMaterialShell's tray host
    # (`StatusNotifierWatcher`, provided by `dms.service`) was up — leaving the
    # app running but with no system-tray icon. Binding to
    # `graphical-session.target` and ordering `After = dms.service` makes login
    # autostart reliable and ensures the tray host exists before insync
    # registers its icon. `--no-daemon` keeps the process in the foreground so
    # systemd (Type=simple) supervises it directly.
    home-manager.users.${globals.user.name} = {
      systemd.user.services.insync = {
        Unit = {
          Description = "Insync Google Drive sync client";
          After = [
            "graphical-session.target"
            "dms.service"
          ];
          PartOf = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          ExecStart = "${pkgs.insync}/bin/insync start --no-daemon";
          ExecStop = "${pkgs.insync}/bin/insync quit";
          Restart = "on-failure";
          RestartSec = 5;
          TimeoutStopSec = 20;
        };
      };
    };
  };
}
