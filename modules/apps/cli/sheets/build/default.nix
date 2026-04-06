{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli.sheets;
in
buildGoModule rec {
  pname = "sheets";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "maaslalani";
    repo = "sheets";
    rev = "v${version}";
    inherit (v) hash;
  };

  inherit (v) vendorHash;

  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "A terminal spreadsheet TUI for CSV files";
    homepage = "https://github.com/maaslalani/sheets";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "sheets";
  };
}
