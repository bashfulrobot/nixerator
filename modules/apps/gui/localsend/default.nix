{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.gui.localsend;
in
{
  options = {
    apps.gui.localsend = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable LocalSend for local file sharing.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    programs.localsend = {
      enable = true;
      openFirewall = true;
    };

    # Autostart LocalSend declaratively rather than relying on the plain
    # ~/.config/autostart/localsend_app.desktop file the app writes itself
    # (which is unmanaged and pins nothing). `--hidden` starts it minimised to
    # the tray. Under UWSM this entry is launched by systemd's
    # xdg-desktop-autostart.target; on non-UWSM hosts hyprflake's dex hook
    # services the same folder. LocalSend has no ordering/supervision needs, so
    # the folder entry is the right fit (unlike Insync, which is a user service).
    home-manager.users.${globals.user.name}.xdg.configFile."autostart/localsend.desktop".text = ''
      [Desktop Entry]
      Type=Application
      Name=LocalSend
      Exec=${pkgs.localsend}/bin/localsend_app --hidden
      Terminal=false
    '';
  };
}
