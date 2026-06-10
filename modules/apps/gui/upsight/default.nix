{
  inputs,
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.apps.gui.upsight;
  upsight-pkg = inputs.upsight.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options = {
    apps.gui.upsight.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Upsight CSM desktop application.";
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [
      upsight-pkg
    ];

    # Workaround (trial) for an intermittent Compose/Skiko-on-Hyprland bug: on
    # window open, the OpenGL render surface sometimes fails to follow the
    # compositor's resize, so the UI draws at 1280x800 in the top-left with
    # black margins; any later resize/move heals it. Investigation showed AWT
    # tracks the window size correctly — the fault is below it, a Skiko GL
    # surface <-> compositor buffer-sync race during Hyprland's open animation.
    # Disabling animations for the window removes the resize churn that triggers
    # it, and keeps GPU rendering (vs forcing -Dskiko.renderApi=SOFTWARE).
    #
    # NOTE: Java/AWT sets WM_CLASS slightly after map, which can defeat
    # class-matched open-time rules. If the open animation still plays (and the
    # bug still occurs), this matcher isn't catching the window early enough and
    # we fall back to software rendering. Validate in normal use.
    home-manager.users.${globals.user.name} = {
      hyprflake.hyprland.extraLua."upsight-noanim" = ''
        hl.window_rule({
          name = "upsight-noanim",
          match = { class = "^(dev-upsight-MainKt)$" },
          no_anim = true,
        })
      '';
    };

  };
}
