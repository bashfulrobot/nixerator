{ lib
, stdenvNoCC
, fetchFromGitHub
, python3
, python3Packages
, wrapGAppsHook3
, gtk3
, libhandy
, gobject-introspection
, makeWrapper
}:
let
  pname = "mv7config";
  version = "unstable-2025-06-18";
  src = fetchFromGitHub {
    owner = "matteodelabre";
    repo = "mv7config";
    rev = "51b83da06eea9439d6ed5dbaf4ab3c5867db6602";
    hash = "sha256-wv8ffjM/8hLWOYzOIp96VInBObz0i+A3453ujZnQ+Yw=";
  };
  pythonPath = python3Packages.makePythonPath [
    python3Packages.pygobject3
    python3Packages.pycairo
    python3Packages.hid
  ];
  sitePackages = "${python3.sitePackages}";
  desktopId = "re.delab.mv7config";
  description = "Unofficial utility for configuring Shure MV7 microphones";
  homepage = "https://github.com/matteodelabre/mv7config";
  license = lib.licenses.gpl3Plus;
  mainProgram = pname;
  maintainers = with lib.maintainers; [ ];
  platforms = lib.platforms.linux;
  meta = {
    inherit description homepage license mainProgram maintainers platforms;
  };
in
stdenvNoCC.mkDerivation {
  inherit pname version src meta;

  nativeBuildInputs = [
    wrapGAppsHook3
    gobject-introspection
    makeWrapper
  ];

  buildInputs = [
    gtk3
    libhandy
  ];

  propagatedBuildInputs = [
    python3Packages.pygobject3
    python3Packages.pycairo
    python3Packages.hid
  ];

  installPhase = ''
    runHook preInstall

    install -Dm644 mv7config/*.py -t "$out/${sitePackages}/mv7config"
    install -Dm644 mv7config/*.ui -t "$out/${sitePackages}/mv7config"

    install -Dm755 gui.py "$out/libexec/${pname}/gui.py"
    install -Dm755 repl.py "$out/libexec/${pname}/repl.py"

    makeWrapper ${python3}/bin/python "$out/bin/${pname}" \
      --add-flags "$out/libexec/${pname}/gui.py" \
      --prefix PYTHONPATH : "$out/${sitePackages}" \
      --prefix PYTHONPATH : "${pythonPath}"

    makeWrapper ${python3}/bin/python "$out/bin/${pname}-repl" \
      --add-flags "$out/libexec/${pname}/repl.py" \
      --prefix PYTHONPATH : "$out/${sitePackages}" \
      --prefix PYTHONPATH : "${pythonPath}"

    install -Dm444 res/${desktopId}.desktop -t "$out/share/applications"
    install -Dm444 res/42-shure-mv7.rules -t "$out/lib/udev/rules.d"

    runHook postInstall
  '';
}
