{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli.plakar;
in
buildGoModule rec {
  pname = "plakar";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "PlakarKorp";
    repo = "plakar";
    rev = "v${version}";
    inherit (v) hash;
  };

  inherit (v) vendorHash;

  # cockroachdb/swiss runtime_go1.20.go has build tag "go1.20 && !go1.26"
  # which excludes Go 1.26+ in nixpkgs; the package provides an escape hatch
  tags = [ "untested_go_version" ];

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Plakar backup tool with deduplication and encryption";
    homepage = "https://github.com/PlakarKorp/plakar";
    license = licenses.isc;
    maintainers = [ ];
    mainProgram = "plakar";
  };
}
