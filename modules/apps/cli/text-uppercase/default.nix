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
      # Hyprflake's hyprland.lua loads ~/.config/hypr/conf.d/*.lua via a
      # dofile loop; .conf files are ignored by the Lua backend.
      xdg.configFile."hypr/conf.d/text-uppercase.lua".text = ''
        hl.bind("SUPER + SHIFT + U",
          hl.dsp.exec_cmd("${pkgs.bash}/bin/bash ${textUppercaseScript}"))
      '';
    };
  };
}
