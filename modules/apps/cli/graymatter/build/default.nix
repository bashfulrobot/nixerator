{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli.graymatter;
in
buildGoModule rec {
  pname = "graymatter";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "angelnicolasc";
    repo = "graymatter";
    rev = "v${version}";
    inherit (v) hash;
  };

  inherit (v) vendorHash;

  overrideModAttrs = _: {
    buildPhase = "export GOWORK=$PWD/go.work && go work vendor";
  };

  preBuild = "export GOWORK=$PWD/go.work";

  subPackages = [ "cmd/graymatter" ];

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "Persistent memory system for AI agents";
    homepage = "https://github.com/angelnicolasc/graymatter";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "graymatter";
  };
}
