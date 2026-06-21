{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.gui.upsight-kotlin;

  # Original Kotlin/Compose Upsight, kept for side-by-side comparison with the
  # Go rewrite (`apps.gui.upsight`). Both upstream packages ship `bin/upsight`,
  # `upsight.desktop`, and `upsight` icons, so this re-wraps the Kotlin build
  # under the `upsight-kotlin` name to avoid collisions in systemPackages.
  upstream = inputs.upsight-kotlin.packages.${pkgs.stdenv.hostPlatform.system}.default;

  upsight-kotlin-pkg =
    pkgs.runCommand "upsight-kotlin-${upstream.version or "0.33.0"}"
      {
        nativeBuildInputs = [ pkgs.makeWrapper ];
        meta = (upstream.meta or { }) // {
          description = "Upsight (Kotlin/Compose original), renamed for side-by-side use";
          mainProgram = "upsight-kotlin";
        };
      }
      ''
        mkdir -p $out/bin
        makeWrapper ${upstream}/bin/upsight $out/bin/upsight-kotlin

        install -Dm644 ${upstream}/share/icons/hicolor/256x256/apps/upsight.png \
          $out/share/icons/hicolor/256x256/apps/upsight-kotlin.png
        install -Dm644 ${upstream}/share/icons/hicolor/scalable/apps/upsight.svg \
          $out/share/icons/hicolor/scalable/apps/upsight-kotlin.svg

        mkdir -p $out/share/applications
        substitute ${upstream}/share/applications/upsight.desktop \
          $out/share/applications/upsight-kotlin.desktop \
          --replace 'Exec=upsight' 'Exec=upsight-kotlin' \
          --replace 'Icon=upsight' 'Icon=upsight-kotlin' \
          --replace 'Name=Upsight' 'Name=Upsight (Kotlin)'
      '';
in
{
  options = {
    apps.gui.upsight-kotlin.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the original Kotlin Upsight desktop app (as `upsight-kotlin`) for comparison with the Go rewrite.";
    };
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [
      upsight-kotlin-pkg
    ];

  };
}
