{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  versions,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "markless";
  inherit (versions.cli.markless) version cargoHash;

  src = fetchFromGitHub {
    owner = "jvanderberg";
    repo = "markless";
    rev = "${versions.cli.markless.tagPrefix}${versions.cli.markless.version}";
    inherit (versions.cli.markless) hash;
  };

  nativeBuildInputs = [ pkg-config ];

  # The test suite drives a terminal and needs a tty.
  doCheck = false;

  meta = {
    description = "Terminal markdown viewer and editor with image support - https://github.com/jvanderberg/markless";
    license = lib.licenses.mit;
    mainProgram = "markless";
  };
}
