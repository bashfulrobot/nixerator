# Local override for Whispering desktop app
# Open-source transcription app with local and cloud engines
#
# TODO: Check for new Whispering releases periodically at:
# https://github.com/EpicenterHQ/epicenter/releases
#
# Last updated: 2026-02-11
# Current version: 7.11.0

{
  lib,
  fetchurl,
  appimageTools,
}:
let
  pname = "whispering";
  version = "7.11.0";

  src = fetchurl {
    url = "https://github.com/EpicenterHQ/epicenter/releases/download/v${version}/Whispering_${version}_amd64.AppImage";
    hash = "sha256-Yxf6jvouW2TOeegtWMMO0TAGGIqv0MES8C81wAsnqBU=";
  };

  meta = {
    homepage = "https://epicenter.so/whispering/";
    description = "Open-source transcription app with local and cloud engines";
    mainProgram = "whispering";
    changelog = "https://github.com/EpicenterHQ/epicenter/releases/tag/v${version}";
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
      desktopSource=""
      for candidate in whispering.desktop Whispering.desktop; do
        if [ -f "${appimageContents}/$candidate" ]; then
          desktopSource="${appimageContents}/$candidate"
          break
        fi
      done

      if [ -n "$desktopSource" ]; then
        install -Dm444 "$desktopSource" "$out/share/applications/whispering.desktop"
        substituteInPlace "$out/share/applications/whispering.desktop" \
          --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=whispering %U' \
          --replace-fail 'Exec=AppRun %U' 'Exec=whispering %U' \
          --replace-fail 'Exec=AppRun' 'Exec=whispering'
      else
        install -d "$out/share/applications"
        cat > "$out/share/applications/whispering.desktop" <<'EOF'
[Desktop Entry]
Name=Whispering
Comment=Open-source transcription app with local and cloud engines
Exec=whispering %U
Terminal=false
Type=Application
Categories=AudioVideo;Audio;Utility;
Icon=whispering
StartupWMClass=Whispering
EOF
      fi

      iconSource=""
      for candidate in whispering.png Whispering.png whispering.svg Whispering.svg; do
        if [ -f "${appimageContents}/$candidate" ]; then
          iconSource="${appimageContents}/$candidate"
          break
        fi
      done

      if [ -n "$iconSource" ]; then
        install -Dm444 "$iconSource" "$out/share/pixmaps/whispering.${iconSource##*.}"
      fi
    '';
}


