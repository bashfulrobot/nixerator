{
  lib,
  rustPlatform,
  fetchFromGitHub,
  versions,
  ...
}:
rustPlatform.buildRustPackage {
  pname = "weave";
  inherit (versions.cli.weave) version cargoHash;

  src = fetchFromGitHub {
    owner = "matze";
    repo = "weave";
    rev = "${versions.cli.weave.tagPrefix}${versions.cli.weave.version}";
    inherit (versions.cli.weave) hash;
  };

  cargoBuildFlags = [
    "--package"
    "weave"
  ];

  doCheck = false;

  meta = {
    description = "Minimalistic self-hosted web frontend for zk notes - https://github.com/matze/weave";
    license = lib.licenses.mit;
    mainProgram = "weave";
  };
}
