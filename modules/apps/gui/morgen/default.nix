{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.gui.morgen;

  # Morgen's Electron 41 GPU process fails to initialise EGL on Wayland in
  # NixOS 25.11 (NixOS/nixpkgs#431637), and Morgen treats the resulting
  # "GPU access not allowed" state as fatal and refuses to start. Force the
  # X11/XWayland ozone backend so Chromium's GPU init path succeeds.
  morgen = pkgs.symlinkJoin {
    name = "morgen-x11";
    paths = [ pkgs.morgen ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/morgen --add-flags --ozone-platform=x11
    '';
  };
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
    environment.systemPackages = [ morgen ];

    home-manager.users.${globals.user.name} = {
      xdg.configFile."hypr/conf.d/morgen-windowrule.conf".text = ''
        windowrule {
            name = morgen-tile
            match:class = ^([Mm]orgen)$
            tile = on
        }
      '';
    };
  };
}
