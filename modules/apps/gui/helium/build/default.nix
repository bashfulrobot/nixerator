# Local package for Helium browser — Chromium-based, privacy-focused
# Version managed in settings/versions.nix

{
  lib,
  fetchurl,
  appimageTools,
  versions,
}:
let
  pname = "helium";
  v = versions.gui.helium;
  inherit (v) version;

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    inherit (v) hash;
  };

  meta = {
    homepage = "https://helium.computer";
    description = "Chromium-based web browser made for people, with best privacy by default, unbiased ad-blocking, no bloat and no noise";
    mainProgram = "helium";
    changelog = "https://github.com/imputnet/helium-linux/releases/tag/${version}";
    license = lib.licenses.gpl3Plus;
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
      install -Dm444 ${appimageContents}/helium.desktop -t $out/share/applications
      install -Dm444 ${appimageContents}/helium.png -t $out/share/pixmaps

      # Fix exec statements in desktop file (most specific first)
      substituteInPlace $out/share/applications/helium.desktop \
        --replace-fail 'Exec=AppRun --incognito' 'Exec=helium --incognito' \
        --replace-fail 'Exec=AppRun %U' 'Exec=helium %U' \
        --replace-fail 'Exec=AppRun' 'Exec=helium'
    '';
}
