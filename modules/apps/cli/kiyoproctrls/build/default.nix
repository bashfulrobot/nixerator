{ lib
, stdenv
, fetchFromGitHub
, makeWrapper
, copyDesktopItems
, makeDesktopItem
, python3
, versions
}:

let
  python = python3.withPackages (ps: [ ps.tkinter ]);
in
stdenv.mkDerivation rec {
  pname = "kiyoproctrls";
  inherit (versions.cli.kiyoproctrls) version;

  src = fetchFromGitHub {
    owner = "soyersoyer";
    repo = "kiyoproctrls";
    inherit (versions.cli.kiyoproctrls) rev;
    hash = versions.cli.kiyoproctrls.sha256;
  };

  nativeBuildInputs = [ makeWrapper copyDesktopItems ];
  buildInputs = [ python ];

  dontBuild = true;

  desktopItems = [
    (makeDesktopItem {
      name = "kiyoproctrls";
      exec = "kiyoproctrlsgui";
      icon = "kiyoproctrls";
      desktopName = "Kiyo Pro Controls";
      genericName = "Webcam Controls";
      comment = "Control Razer Kiyo Pro webcam settings";
      categories = [ "Utility" "Settings" "HardwareSettings" ];
    })
  ];

  installPhase = ''
    mkdir -p $out/bin
    mkdir -p $out/share/icons/hicolor/256x256/apps

    # Install CLI tool
    cp kiyoproctrls.py $out/bin/kiyoproctrls
    chmod +x $out/bin/kiyoproctrls

    # Install GUI tool
    cp kiyoproctrlsgui.py $out/bin/kiyoproctrlsgui
    chmod +x $out/bin/kiyoproctrlsgui

    # Install icon
    cp kiyopro_240.png $out/share/icons/hicolor/256x256/apps/kiyoproctrls.png

    wrapProgram $out/bin/kiyoproctrls \
      --prefix PATH : ${lib.makeBinPath [ python ]}

    wrapProgram $out/bin/kiyoproctrlsgui \
      --prefix PATH : ${lib.makeBinPath [ python ]}
  '';

  meta = with lib; {
    description = "Control Razer Kiyo Pro webcam settings (HDR, FoV, autofocus)";
    homepage = "https://github.com/soyersoyer/kiyoproctrls";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "kiyoproctrls";
  };
}
