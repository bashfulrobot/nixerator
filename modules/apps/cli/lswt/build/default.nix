{ lib
, stdenv
, fetchFromSourcehut
, pkg-config
, wayland
, wayland-scanner
, wayland-protocols
}:

stdenv.mkDerivation rec {
  pname = "lswt";
  version = "2.0.0";

  src = fetchFromSourcehut {
    owner = "~leon_plickat";
    repo = pname;
    rev = "v${version}";
    hash = "sha256-8jP6I2zsDt57STtuq4F9mcsckrjvaCE5lavqKTjhNT0=";
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
