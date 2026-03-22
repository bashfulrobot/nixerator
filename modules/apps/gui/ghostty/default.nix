{
  config,
  lib,
  pkgs,
  globals,
  ...
}:
let
  cfg = config.apps.gui.ghostty;
in
{
  options = {
    apps.gui.ghostty.enable = lib.mkEnableOption "the Ghostty terminal emulator";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      programs.ghostty = {
        enable = true;
        package = pkgs.ghostty;
        enableFishIntegration = true;
        installBatSyntax = true;
        settings = {
          window-decoration = false;
          window-padding-x = 20;
          window-padding-y = 20;
          keybind = [
            "scroll_lock=unbind"
          ];
        };
      };
    };
  };
}
