{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

# Jellyfin MPV Shim
# Direct-play Jellyfin client: exposes this machine as a play target in the
# Jellyfin phone/web apps and plays through mpv (full HEVC/HDR10/DV-base/AV1
# via VAAPI on the GPU, no server transcode). Chosen over the native
# `jellyfin-desktop` package, which nixpkgs pins to a tagless pre-release
# whose mpv renderer is broken on Wayland (`vo/libmpv: No render context set`).

let
  cfg = config.apps.gui.jellyfin-mpv-shim;
in
{
  options = {
    apps.gui.jellyfin-mpv-shim = {
      enable = lib.mkEnableOption "Jellyfin MPV Shim direct-play client";

      autostart = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = ''
          Autostart the shim as a systemd user service so it is always
          available as a Jellyfin play/cast target. Disable to launch it on
          demand with `jellyfin-mpv-shim` instead.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.jellyfin-mpv-shim ];

    # Autostart as a systemd user service rather than a hyprland `exec-once`
    # lua hook: a lua hook has no supervision or ordering, so the shim could
    # launch before DankMaterialShell's tray host (`StatusNotifierWatcher`,
    # provided by `dms.service`) was up, leaving it running with no tray icon.
    # Binding to `graphical-session.target` and ordering `After = dms.service`
    # makes login autostart reliable and ensures the tray host exists before
    # the shim registers its icon. First run still prompts (once) for the
    # server URL and login through its config GUI.
    home-manager.users.${globals.user.name} = lib.mkIf cfg.autostart {
      systemd.user.services.jellyfin-mpv-shim = {
        Unit = {
          Description = "Jellyfin MPV Shim direct-play client";
          After = [
            "graphical-session.target"
            "dms.service"
          ];
          PartOf = [ "graphical-session.target" ];
        };
        Install.WantedBy = [ "graphical-session.target" ];
        Service = {
          ExecStart = "${pkgs.jellyfin-mpv-shim}/bin/jellyfin-mpv-shim";
          Restart = "on-failure";
          RestartSec = 5;
        };
      };
    };
  };
}
