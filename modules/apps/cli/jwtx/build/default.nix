{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli.jwtx;
in
buildGoModule rec {
  pname = "jwtx";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "gurleensethi";
    repo = "jwtx";
    rev = version;
    inherit (v) hash;
  };

  inherit (v) vendorHash;

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "A terminal JWT decoder/encoder TUI";
    homepage = "https://github.com/gurleensethi/jwtx";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "jwtx";
  };
}
