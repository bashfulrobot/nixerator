{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  zstd,
  oniguruma,
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

  # zstd-sys and onig_sys probe for libzstd and oniguruma through pkg-config.
  # Newer nixpkgs no longer supplies these to Rust builds implicitly.
  nativeBuildInputs = [ pkg-config ];
  buildInputs = [
    zstd
    oniguruma
  ];

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
