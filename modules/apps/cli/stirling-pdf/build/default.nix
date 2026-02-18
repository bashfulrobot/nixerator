{ lib, pkgs, versions, ... }:

let
  ver = versions.services.stirling-pdf;
in
pkgs.stdenv.mkDerivation {
  name = "stirling-pdf-${ver.version}";

  dontUnpack = true;
  dontBuild = true;

  jar = pkgs.fetchurl {
    url = "https://github.com/Stirling-Tools/Stirling-PDF/releases/download/v${ver.version}/Stirling-PDF-with-login.jar";
    sha256 = ver.sha256;
  };

  icon = pkgs.fetchurl {
    url = "https://raw.githubusercontent.com/Stirling-Tools/Stirling-PDF/main/docs/stirling.svg";
    sha256 = ver.iconSha256;
  };

  installPhase = ''
    mkdir -p $out/share/stirling-pdf
    cp $jar $out/share/stirling-pdf/Stirling-PDF.jar
    cp $icon $out/share/stirling-pdf/stirling.svg
  '';

  meta = with lib; {
    description = "Stirling PDF v${ver.version} (with-login)";
    homepage = ver.repo;
  };
}
