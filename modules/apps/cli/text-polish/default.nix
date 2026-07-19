{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.text-polish;

  textPolishScript = pkgs.replaceVars ./scripts/text-polish.sh {
    wl_paste = "${pkgs.wl-clipboard}/bin/wl-paste";
    wl_copy = "${pkgs.wl-clipboard}/bin/wl-copy";
    notify_send = "${pkgs.libnotify}/bin/notify-send";
    wtype = "${pkgs.wtype}/bin/wtype";
    jq = "${pkgs.jq}/bin/jq";
    timeout = "${pkgs.coreutils}/bin/timeout";
    od = "${pkgs.coreutils}/bin/od";
    tr = "${pkgs.coreutils}/bin/tr";
    # Concision/anti-slop rules, single-sourced so the keybind filter and the
    # claude-code `text-polish` skill can never drift apart.
    rules_file = "${cfg.rulesFile}";
  };
in
{
  options.apps.cli.text-polish = {
    enable = lib.mkEnableOption "Text polish keyboard shortcut — rewrite selected text via Claude";

    rulesFile = lib.mkOption {
      type = lib.types.path;
      default = ./prompt/concision-rules.md;
      readOnly = true;
      description = ''
        Shared concision/anti-slop rewrite rules. Single source of truth consumed
        by both the SUPER+SHIFT+R keybind filter (this module) and the claude-code
        `text-polish` skill (installed into its references at activation), so the
        two can never drift.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      # Declared through hyprflake.hyprland.extraLua (hyprflake writes the file
      # and requires it at the end of hyprland.lua).
      hyprflake.hyprland.extraLua."text-polish" = ''
        hl.bind("SUPER + SHIFT + R",
          hl.dsp.exec_cmd("${pkgs.bash}/bin/bash ${textPolishScript}"))
      '';
    };
  };
}
