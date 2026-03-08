{
  lib,
  buildGoModule,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli.lazyrestic;
in
buildGoModule rec {
  pname = "lazyrestic";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "craigderington";
    repo = "lazyrestic";
    inherit (v) rev hash;
  };

  inherit (v) vendorHash;

  # Skip tests due to filesystem-specific test dependencies
  doCheck = false;

  ldflags = [
    "-s"
    "-w"
  ];

  meta = with lib; {
    description = "A TUI for managing restic backups";
    homepage = "https://github.com/craigderington/lazyrestic";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "lazyrestic";
  };
}
