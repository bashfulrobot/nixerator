# Local package for PCtrl process manager
# Rust + Tauri-based process manager with TUI and GUI interfaces
#
# TODO: Check for new PCtrl releases periodically at:
# https://github.com/MohamedSherifNoureldin/PCtrl/releases
#
# Last updated: 2026-01-29
# Current version: 1.0.0

{
  lib,
  fetchurl,
  appimageTools,
}:
let
  pname = "pctrl";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/MohamedSherifNoureldin/PCtrl/releases/download/v${version}/${pname}_${version}_amd64.AppImage";
    hash = "sha256-JkdHgkiERGXmskMKCoAwINnX2agoEfTUplYfGnvzAcw=";
  };

  meta = {
    homepage = "https://github.com/MohamedSherifNoureldin/PCtrl";
    description = "A robust, featureful, easy-to-use and powerful process manager based on Rust";
    mainProgram = "pctrl";
    changelog = "https://github.com/MohamedSherifNoureldin/PCtrl/releases/tag/v${version}";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
in
appimageTools.wrapType2 {
  inherit
    pname
    version
    src
    meta
    ;

  extraInstallCommands =
    let
      appimageContents = appimageTools.extract {
        inherit pname version src;
      };
    in
    ''
      # Install XDG Desktop file and its icon
      install -Dm444 ${appimageContents}/pctrl.desktop -t $out/share/applications
      install -Dm444 ${appimageContents}/pctrl.png -t $out/share/pixmaps
    '';
}
