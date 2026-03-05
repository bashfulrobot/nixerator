{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.gui.morgen;
in
{
  options = {
    apps.gui.morgen.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Morgen calendar application.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      morgen
    ];

    home-manager.users.${globals.user.name} = {
      xdg.configFile."hypr/conf.d/morgen-windowrule.conf".text = ''
        windowrule = tile, class:^([Mm]orgen)$
      '';
    };
  };
}
