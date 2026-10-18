{
  lib,
  rustPlatform,
  fetchFromGitHub,
  pkg-config,
  versions,
}:

let
  v = versions.cli.dnsglobe;
in
rustPlatform.buildRustPackage rec {
  pname = "dnsglobe";
  inherit (v) version;

  src = fetchFromGitHub {
    owner = "514-labs";
    repo = "dnsglobe";
    rev = "v${version}";
    inherit (v) hash;
  };

  inherit (v) cargoHash;

  nativeBuildInputs = [ pkg-config ];

  doCheck = false;

  meta = with lib; {
    description = "Global DNS propagation checker TUI - watch a record propagate across 34 public resolvers";
    homepage = "https://github.com/514-labs/dnsglobe";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "dnsglobe";
  };
}
