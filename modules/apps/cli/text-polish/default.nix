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
  };

  textPolishVoiceScript = pkgs.replaceVars ./scripts/text-polish-voice.sh {
    wl_paste = "${pkgs.wl-clipboard}/bin/wl-paste";
    wl_copy = "${pkgs.wl-clipboard}/bin/wl-copy";
    notify_send = "${pkgs.libnotify}/bin/notify-send";
  };
in
{
  options.apps.cli.text-polish.enable =
    lib.mkEnableOption "Text polish keyboard shortcuts — rewrite selected text via Claude";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      xdg.configFile."hypr/conf.d/text-polish.conf".text = ''
        bind = SUPER SHIFT, R, exec, ${pkgs.bash}/bin/bash ${textPolishVoiceScript}
      '';
      xdg.configFile."hypr/conf.d/text-polish-generic.conf".text = ''
        bind = SUPER CTRL, R, exec, ${pkgs.bash}/bin/bash ${textPolishScript}
      '';
    };
  };
}
