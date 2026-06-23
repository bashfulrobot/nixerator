{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

# Clipboard/hotkey companion to the Zoom web wrap (default.nix). Copy a Zoom or
# Clari meeting link (or a bare meeting id) anywhere, press SUPER+SHIFT+Z, and
# the meeting opens in the dedicated Zoom PWA profile via the web client.
#
# Mirrors the text-polish module: a wl-paste-driven script wired to a keybind
# through hyprflake.hyprland.extraLua. Gated on the Zoom wrap being enabled
# (apps.webapps.zoom.enable, defined by default.nix) since it reuses the wrap's
# Chrome profile and login.
let
  cfg = config.apps.webapps.zoom;

  zoomJoinScript = pkgs.replaceVars ./scripts/zoom-join.sh {
    wl_paste = "${pkgs.wl-clipboard}/bin/wl-paste";
    notify_send = "${pkgs.libnotify}/bin/notify-send";
    # Resolve the browser via the system profile so the script tracks
    # globals.preferences.browser (same approach as the claude-code module).
    browser = "/run/current-system/sw/bin/${globals.preferences.browser}";
    # Same per-PWA profile dir that mkWebApp launches the Zoom wrap with, so
    # the joined meeting shares the wrap's login/cookies.
    profile = "${globals.user.homeDirectory}/.config/google-chrome-zoom";
  };
in
{
  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      hyprflake.hyprland.extraLua."zoom-join" = ''
        hl.bind("SUPER + SHIFT + Z",
          hl.dsp.exec_cmd("${pkgs.bash}/bin/bash ${zoomJoinScript}"), { description = "Join Zoom meeting from clipboard" })
      '';
    };
  };
}
