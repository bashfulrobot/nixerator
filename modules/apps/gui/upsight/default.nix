{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.gui.upsight;
  upsight-base = inputs.upsight.packages.${pkgs.stdenv.hostPlatform.system}.default;

  # Force Skiko's software renderer for upsight.
  #
  # On Hyprland/XWayland the Compose/Skiko OpenGL render surface intermittently
  # fails to follow the compositor's resize on window open, so the UI draws at
  # 1280x800 in the top-left with black margins until any later resize/move
  # heals it. Investigation showed AWT tracks the window size correctly — the
  # fault is below it, in Skiko's hardware-GL surface <-> compositor buffer sync.
  # A Hyprland `no_anim` window rule (disabling the open animation) did NOT fix
  # it on a fresh launch, ruling out animation churn as the trigger. Selecting
  # the software renderer sidesteps the GL surface entirely and resolves the
  # black margins; the trade-off is CPU rasterization, which is fine for this
  # business-data UI.
  #
  # Skiko reads the SKIKO_RENDER_API env var (it takes precedence over the
  # -Dskiko.renderApi system property), so this needs no upsight release — just
  # a wrapper around the packaged binary. The packaged `upsight` is itself a
  # wrapper script (it sets the Mesa LD_LIBRARY_PATH); makeWrapper prepends the
  # env var and the original wrapper still runs underneath.
  upsight-pkg = pkgs.symlinkJoin {
    name = "upsight-swrender";
    paths = [ upsight-base ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/upsight \
        --set SKIKO_RENDER_API SOFTWARE
    '';
  };
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

  };
}
