{
  globals,
  lib,
  pkgs,
  config,
  ...
}:

# Insync Module
# Google Drive sync client with Nautilus integration

let
  cfg = config.apps.gui.insync;
in
{
  options = {
    apps.gui.insync = {
      enable = lib.mkEnableOption "Insync Google Drive sync client";

      nautilusIntegration = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Nautilus file manager integration for Insync.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages =
      with pkgs;
      [ insync ] ++ lib.optionals cfg.nautilusIntegration [ insync-nautilus ];

    # Autostart insync. The Lua backend has no `exec-once` keyword — register a
    # `hyprland.start` event handler, declared through hyprflake.hyprland.extraLua.
    home-manager.users.${globals.user.name} = {
      hyprflake.hyprland.extraLua."insync-autostart" = ''
        hl.on("hyprland.start", function()
          hl.exec_cmd("insync start --no-daemon")
        end)
      '';
    };
  };
}
