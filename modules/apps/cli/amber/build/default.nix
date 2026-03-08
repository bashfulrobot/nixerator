{
  lib,
  pkgs,
  versions,
  ...
}:
pkgs.stdenv.mkDerivation {
  name = "amber";
  src = pkgs.fetchurl {
    url = "https://github.com/dalance/amber/releases/download/v${versions.cli.amber.version}/amber-v${versions.cli.amber.version}-x86_64-lnx.zip";
    inherit (versions.cli.amber) hash;
  };

  nativeBuildInputs = [ pkgs.unzip ];

  dontBuild = true;

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp ambs $out/bin/ambs
    cp ambr $out/bin/ambr
    chmod +x $out/bin/ambs $out/bin/ambr
  '';

  meta = with lib; {
    description = "Code search and replace tool providing ambs (search) and ambr (replace) - https://github.com/dalance/amber";
    maintainers = [ ];
  };
}
