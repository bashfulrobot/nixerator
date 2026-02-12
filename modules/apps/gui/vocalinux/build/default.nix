{
  lib,
  pkgs,
  python3Packages,
  versions,
  ...
}:

let
  vosk = pkgs.callPackage ./vosk.nix { inherit python3Packages; };
in

python3Packages.buildPythonApplication rec {
  pname = "vocalinux";
  version = versions.gui.vocalinux.version;
  format = "pyproject";

  src = pkgs.fetchFromGitHub {
    owner = "jatinkrmalik";
    repo = "vocalinux";
    rev = "v${version}";
    inherit (versions.gui.vocalinux) hash;
  };

  nativeBuildInputs = with pkgs; [
    gobject-introspection
    wrapGAppsHook3
  ];

  buildInputs = with pkgs; [
    gtk3
    portaudio
  ];

  propagatedBuildInputs = [
    vosk
  ]
  ++ (with python3Packages; [
    pydub
    pynput
    evdev
    requests
    tqdm
    numpy
    pyaudio
    xlib
    pygobject3
  ]);

  # Runtime dependencies for text injection
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

  # Skip tests that require audio hardware
  doCheck = false;

  # Ensure GTK and GObject introspection work properly
  dontWrapGApps = false;

  pythonImportsCheck = [
    "vocalinux"
    "vocalinux.main"
  ];

  meta = with lib; {
    description = "Voice-to-text dictation for Linux with VOSK offline recognition";
    homepage = "https://github.com/jatinkrmalik/vocalinux";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [ ];
  };
}
