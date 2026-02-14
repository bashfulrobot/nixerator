{ lib, pkgs, versions, ... }:
pkgs.stdenv.mkDerivation {
  name = "cpx";
  src = pkgs.fetchurl {
    url =
      "https://github.com/11happy/cpx/releases/download/v${versions.cli.cpx.version}/cpx-linux-x86_64-musl.tar.gz";
    inherit (versions.cli.cpx) sha256;
  };

  dontBuild = true;

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp cpx $out/bin/cpx
    chmod +x $out/bin/cpx
  '';

  meta = with lib; {
    description =
      "Fast, Rust-based cp replacement with progress bars and resume capability - https://github.com/11happy/cpx";
    maintainers = [ ];
  };
}
