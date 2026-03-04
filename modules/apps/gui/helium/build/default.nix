# Local package for Helium browser — Chromium-based, privacy-focused
# Check for updates: just setup::check-updates

{
  lib,
  fetchurl,
  appimageTools,
}:
let
  pname = "helium";
  version = "0.9.1.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    hash = "sha256-0Kw8Ko41Gdz4xLn62riYAny99Hd0s7/75h8bz4LUuCE=";
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
