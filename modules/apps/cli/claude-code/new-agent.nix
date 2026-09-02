{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

# Linux/Hyprland counterpart to donkeykong's Raycast "New Claude Agent"
# script (raycast-scripts/claude-new-agent.sh): press a hotkey, pick a folder
# via a native GTK folder-chooser dialog, and start a NAMED background
# Claude Code session there with Remote Control enabled -- the point is to
# reach the bare `claude` fish wrapper's launch behaviour (cfg/fish.nix) with
# no shell open yet, from any folder, git or not.
#
# Uses zenity's folder chooser rather than driving Nautilus itself: Nautilus
# has no "pick and return a path" mode to script against, while zenity's
# dialog is the same GtkFileChooserNative widget family Nautilus is built on
# (bookmarks sidebar, GVFS locations, recent places), so it looks and
# behaves like browsing in Nautilus.
#
# Companion file to default.nix, same pattern as the zoom module's
# clipboard-join.nix -- reuses the parent module's own `cfg.enable` rather
# than a separate option, since this is inert without claude-code itself.
# Gated additionally on serverProfile == "full" (the same workstation-only
# signal default.nix already uses for libnotify/sox): srv is a headless
# host with no hyprflake.hyprland module imported at all, so unconditionally
# setting hyprflake.hyprland.extraLua would break its evaluation.
let
  cfg = config.apps.cli.claude-code;

  newAgentScript = pkgs.replaceVars ./scripts/new-agent.sh {
    zenity = "${pkgs.zenity}/bin/zenity";
    claude = "${pkgs.llm-agents.claude-code}/bin/claude";
    wl_copy = "${pkgs.wl-clipboard}/bin/wl-copy";
    notify_send = "${pkgs.libnotify}/bin/notify-send";
  };
in
{
  config = lib.mkIf (cfg.enable && cfg.serverProfile == "full") {
    home-manager.users.${globals.user.name} = {
      # Declared through hyprflake.hyprland.extraLua (hyprflake writes the
      # file and requires it at the end of hyprland.lua).
      hyprflake.hyprland.extraLua."claude-new-agent" = ''
        hl.bind("CTRL + SHIFT + SUPER + C",
          hl.dsp.exec_cmd("${pkgs.bash}/bin/bash ${newAgentScript}"), { description = "Start a new Claude agent in a chosen folder" })
      '';
    };
  };
}
