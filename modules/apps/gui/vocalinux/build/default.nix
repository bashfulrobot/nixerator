{
  lib,
  pkgs,
  python3Packages,
  versions,
  ...
}:

let
  vosk = pkgs.callPackage ./vosk.nix { inherit python3Packages; };
  pywhispercpp = pkgs.callPackage ./pywhispercpp.nix { inherit python3Packages; };
in

python3Packages.buildPythonApplication rec {
  pname = "vocalinux";
  inherit (versions.gui.vocalinux) version;
  format = "pyproject";

  src = pkgs.fetchFromGitHub {
    owner = "jatinkrmalik";
    repo = "vocalinux";
    rev = "v${version}";
    inherit (versions.gui.vocalinux) hash;
  };

  nativeBuildInputs =
    with pkgs;
    [
      gobject-introspection
      wrapGAppsHook3
    ]
    ++ (with python3Packages; [
      setuptools
      wheel
    ]);

  buildInputs = with pkgs; [
    gtk3
    libayatana-appindicator
    portaudio
  ];

  propagatedBuildInputs = [
    vosk
    pywhispercpp
  ]
  ++ (with python3Packages; [
    pydub
    pynput
    evdev
    requests
    tqdm
    numpy
    psutil
    pyaudio
    xlib
    pygobject3
  ]);

  makeWrapperArgs = [
    "--prefix PATH : ${
      lib.makeBinPath (
        with pkgs;
        [
          wtype
          xdotool
        ]
      )
    }"
  ];

  doCheck = false;

  dontWrapGApps = false;

  pythonImportsCheck = [
    "vocalinux"
    "vocalinux.main"
  ];

  meta = with lib; {
    description = "Voice-to-text dictation for Linux with whisper.cpp and VOSK recognition";
    homepage = "https://github.com/jatinkrmalik/vocalinux";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
  };
}
