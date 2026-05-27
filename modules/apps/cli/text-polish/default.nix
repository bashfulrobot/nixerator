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
      # Hyprflake's hyprland.lua loads ~/.config/hypr/conf.d/*.lua via a
      # dofile loop; .conf files are ignored by the Lua backend.
      xdg.configFile."hypr/conf.d/text-polish.lua".text = ''
        hl.bind("SUPER + SHIFT + R",
          hl.dsp.exec_cmd("${pkgs.bash}/bin/bash ${textPolishScript}"))
      '';
    };
  };
}
