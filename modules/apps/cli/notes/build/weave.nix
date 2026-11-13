{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  zstd,
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

  # zstd-sys probes for libzstd through pkg-config. Newer nixpkgs no longer
  # supplies pkg-config to Rust builds implicitly.
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [ zstd ];

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
