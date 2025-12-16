{ lib, pkgs, versions, ... }:
pkgs.stdenv.mkDerivation {
  name = "meetsum";
  src = pkgs.fetchurl {
    url =
      "https://github.com/bashfulrobot/meetsum/releases/download/v${versions.cli.meetsum.version}/meetsum-linux-amd64";
    sha256 = versions.cli.meetsum.sha256;
  };
  phases = [ "installPhase" "patchPhase" ];
  installPhase = ''
    mkdir -p $out/bin
    cp $src $out/bin/meetsum
    chmod +x $out/bin/meetsum
  '';

  meta = with lib; {
    description =
      "AI-powered meeting summarizer - https://github.com/bashfulrobot/meetsum.";
    maintainers = [ bashfulrobot ];
  };
}
