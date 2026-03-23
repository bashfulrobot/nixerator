{
  lib,
  pkgs,
  config,
  inputs,
  globals,
  ...
}:

let
  cfg = config.apps.gui.wayscriber;
  wayscriber-pkg = inputs.wayscriber.packages.${pkgs.stdenv.hostPlatform.system}.default;

  toggleScript = pkgs.writeShellScript "wayscriber-toggle" ''
    if ${pkgs.procps}/bin/pgrep -x wayscriber > /dev/null; then
      ${pkgs.procps}/bin/pkill -x wayscriber
    else
      ${wayscriber-pkg}/bin/wayscriber --active --no-resume-session &
    fi
  '';
in
{
  options = {
    apps.gui.wayscriber.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Wayscriber real-time screen annotation tool for Wayland.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      wayscriber-pkg
    ];

    home-manager.users.${globals.user.name} = {
      xdg.configFile."wayscriber/config.toml".text = ''
        [keybindings]
        select_step_marker_tool = ["S"]
        reset_step_markers = ["Ctrl+Shift+R"]
      '';

      xdg.configFile."hypr/conf.d/wayscriber.conf".text = ''
        bind = SUPER, A, exec, ${toggleScript}
      '';
    };
  };
}
