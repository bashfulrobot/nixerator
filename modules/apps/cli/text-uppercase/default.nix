{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.cli.text-uppercase;

  textUppercaseScript = pkgs.replaceVars ./scripts/text-uppercase.sh {
    wl_paste = "${pkgs.wl-clipboard}/bin/wl-paste";
    wl_copy = "${pkgs.wl-clipboard}/bin/wl-copy";
    notify_send = "${pkgs.libnotify}/bin/notify-send";
    tr = "${pkgs.coreutils}/bin/tr";
    wtype = "${pkgs.wtype}/bin/wtype";
  };
in
{
  options.apps.cli.text-uppercase.enable =
    lib.mkEnableOption "Text uppercase keyboard shortcut — convert selected text to ALL CAPS";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      # Declared through hyprflake.hyprland.extraLua (hyprflake writes the file
      # and requires it at the end of hyprland.lua).
      hyprflake.hyprland.extraLua."text-uppercase" = ''
        hl.bind("SUPER + SHIFT + U",
          hl.dsp.exec_cmd("${pkgs.bash}/bin/bash ${textUppercaseScript}"))
      '';
    };
  };
}
