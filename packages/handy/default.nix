# Local package for Handy speech-to-text
# Free, open source, offline speech-to-text application
#
# TODO: Check for new Handy releases periodically at:
# https://github.com/cjpais/Handy/releases
#
# Last updated: 2026-02-03
# Current version: 0.7.1
#
# Version bump process documented in: ../VERSION-TRACKING.md

{
  lib,
  fetchurl,
  appimageTools,
  makeDesktopItem,
}:
let
  pname = "handy";
  version = "0.7.1";

  src = fetchurl {
    url = "https://github.com/cjpais/Handy/releases/download/v${version}/Handy_${version}_amd64.AppImage";
    hash = "sha256-7IUZZriIVmqf85O49w9tCrTKfQURuAOM+k3sKVyigFk=";
  };

  desktopItem = makeDesktopItem {
    name = "handy";
    desktopName = "Handy";
    comment = "Privacy-first offline speech-to-text";
    exec = "handy %U";
    icon = "handy";
    terminal = false;
    type = "Application";
    categories = [
      "Utility"
      "Accessibility"
      "Audio"
    ];
    keywords = [
      "speech"
      "voice"
      "transcription"
      "whisper"
      "dictation"
    ];
  };

  meta = {
    homepage = "https://handy.computer";
    description = "Free, open source, and extensible speech-to-text application that works completely offline";
    mainProgram = "handy";
    changelog = "https://github.com/cjpais/Handy/releases/tag/v${version}";
    license = lib.licenses.agpl3Plus;
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
      # Install desktop file
      install -Dm444 ${desktopItem}/share/applications/handy.desktop -t $out/share/applications

      # Install icon from AppImage
      install -Dm444 ${appimageContents}/handy.png -t $out/share/pixmaps
    '';
}
