{
  lib,
  stdenv,
  fetchFromSourcehut,
  pkg-config,
  wayland,
  wayland-scanner,
  wayland-protocols,
  versions,
}:

let
  v = versions.cli.lswt;
in
stdenv.mkDerivation rec {
  pname = "lswt";
  inherit (v) version;

  src = fetchFromSourcehut {
    owner = "~leon_plickat";
    repo = pname;
    rev = "v${version}";
    inherit (v) hash;
  };

  nativeBuildInputs = [
    pkg-config
    wayland-scanner
  ];

  buildInputs = [
    wayland
    wayland-protocols
  ];

  makeFlags = [
    "PREFIX=$(out)"
  ];

  meta = with lib; {
    description = "List Wayland toplevels (open windows in Wayland desktop environments)";
    homepage = "https://git.sr.ht/~leon_plickat/lswt";
    license = licenses.gpl3Only;
    platforms = platforms.linux;
    maintainers = [ ];
    mainProgram = "lswt";
  };
}
