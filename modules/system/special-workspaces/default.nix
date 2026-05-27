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
      # Special workspaces: named, toggled by shortcut.
      # SUPER+W = Work, SUPER+O = Office, SUPER+M = Music, SUPER+D = Dev.
      # Lua backend: hyprflake's hyprland.lua loads conf.d/*.lua via dofile.
      xdg.configFile."hypr/conf.d/special-workspaces.lua".text = ''
        local function toggle(name)
          return hl.dsp.workspace.toggle_special(name)
        end
        local function move_to(name)
          return hl.dsp.window.move({ workspace = "special:" .. name })
        end

        hl.bind("SUPER + W",         toggle("work"))
        hl.bind("SUPER + SHIFT + W", move_to("work"))
        hl.bind("SUPER + O",         toggle("office"))
        hl.bind("SUPER + SHIFT + O", move_to("office"))
        hl.bind("SUPER + M",         toggle("music"))
        hl.bind("SUPER + SHIFT + M", move_to("music"))
        hl.bind("SUPER + D",         toggle("dev"))
        hl.bind("SUPER + SHIFT + D", move_to("dev"))
      '';
    };
  };
}
