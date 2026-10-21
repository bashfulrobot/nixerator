{
  lib,
  pkgs,
  versions,
  ...
}:
pkgs.stdenv.mkDerivation {
  pname = "kongctl";
  inherit (versions.cli.kongctl) version;

  src = pkgs.fetchurl {
    url = "https://github.com/${versions.cli.kongctl.repo}/releases/download/${versions.cli.kongctl.tagPrefix}${versions.cli.kongctl.version}/kongctl_linux_amd64.zip";
    inherit (versions.cli.kongctl) hash;
  };

  nativeBuildInputs = [ pkgs.unzip ];

  dontBuild = true;

  sourceRoot = ".";

  installPhase = ''
    install -Dm755 kongctl $out/bin/kongctl
  '';

  meta = with lib; {
    description = "kongctl - declarative CLI for Kong Konnect - https://github.com/Kong/kongctl";
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
