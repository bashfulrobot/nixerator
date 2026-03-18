{
  lib,
  config,
  globals,
  ...
}:

let
  cfg = config.system.special-workspaces;
in
{
  options.system.special-workspaces.enable = lib.mkEnableOption "Hyprland special workspaces for task, office, music, and dev apps";

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      xdg.configFile."hypr/conf.d/special-workspaces.conf".text = ''
        # Special Workspaces: named special workspaces toggled by shortcut
        # SUPER+W = Work, SUPER+O = Office, SUPER+M = Music, SUPER+D = Dev

        # Keybinds: toggle and move-to
        bind = SUPER, W, togglespecialworkspace, work
        bind = SUPER SHIFT, W, movetoworkspace, special:work
        bind = SUPER, O, togglespecialworkspace, office
        bind = SUPER SHIFT, O, movetoworkspace, special:office
        bind = SUPER, M, togglespecialworkspace, music
        bind = SUPER SHIFT, M, movetoworkspace, special:music
        bind = SUPER, D, togglespecialworkspace, dev
        bind = SUPER SHIFT, D, movetoworkspace, special:dev

      '';
    };
  };
}
