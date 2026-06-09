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
  };
in
{
  options.apps.cli.text-polish.enable =
    lib.mkEnableOption "Text polish keyboard shortcut — rewrite selected text via Claude";

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
