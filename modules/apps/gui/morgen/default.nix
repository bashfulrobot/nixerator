{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.gui.morgen;

  # Morgen 4.0.4 has a Linux-only bug: `dist/main.js` unconditionally calls
  # `app.disableHardwareAcceleration()` on non-darwin/non-win32 platforms,
  # then a Sentry `GpuContext` event processor calls `app.getGPUInfo()`
  # which throws "GPU access not allowed" because acceleration was just
  # disabled. The unhandled async rejection kills the main process before
  # the window opens. Patch the asar to neuter the disable call.
  morgen = pkgs.morgen.overrideAttrs (old: {
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.asar ];
    postFixup = (old.postFixup or "") + ''
      asarFile=$out/opt/Morgen/resources/app.asar
      work=$(mktemp -d)
      asar extract "$asarFile" "$work"
      substituteInPlace "$work/dist/main.js" \
        --replace-fail 'ee.app.disableHardwareAcceleration()' 'ee.app.getName()'
      asar pack "$work" "$asarFile"
      rm -rf "$work"
    '';
  });
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
