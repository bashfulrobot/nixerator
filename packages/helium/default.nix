# Local package for Helium browser
# Chromium-based web browser focused on privacy and ad-blocking
#
# TODO: Check for new Helium releases periodically at:
# https://github.com/imputnet/helium-linux/releases
#
# Last updated: 2026-01-16
# Current version: 0.7.10.1
#
# Note: Helium is currently beta software
# Version bump process documented in: ../VERSION-TRACKING.md

{
  lib,
  stdenv,
  fetchurl,
  appimageTools,
}:
let
  pname = "helium";
  version = "0.7.10.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    hash = "sha256-11xSlHIqmyyVwjjwt5FmLhp72P3m07PppOo7a9DbTcE=";
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
