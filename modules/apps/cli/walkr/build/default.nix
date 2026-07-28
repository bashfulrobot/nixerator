{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli.walkr;
in
buildGoModule rec {
  pname = "walkr";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "bashfulrobot";
    repo = "walkr";
    inherit (v) rev;
    inherit (v) hash;
    rev = v.rev;
  };

  inherit (v) vendorHash;

  env.CGO_ENABLED = "0";

  ldflags = [
    "-s"
    "-w"
  ];

  doCheck = false;

  meta = with lib; {
    description = "Renders hand-authored walkthroughs into a static wizard-style teaching site";
    homepage = "https://github.com/bashfulrobot/walkr";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "walkr";
  };
}
