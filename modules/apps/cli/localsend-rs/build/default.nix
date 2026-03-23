{
  lib,
  rustPlatform,
  fetchFromGitHub,
  versions,
}:

let
  v = versions.cli.localsend-rs;
in
rustPlatform.buildRustPackage rec {
  pname = "localsend-rs";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "CrossCopy";
    repo = "localsend-rs";
    rev = v.rev;
    inherit (v) hash;
  };

  inherit (v) cargoHash;

  buildFeatures = [ "all" ];

  doCheck = false;

  meta = with lib; {
    description = "Rust implementation of LocalSend protocol for local file/text transfer";
    homepage = "https://github.com/CrossCopy/localsend-rs";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "localsend-rs";
  };
}
