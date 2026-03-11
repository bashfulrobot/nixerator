{
  lib,
  pkgs,
  versions,
}:

let
  v = versions.cli.plannotator;
  mainBin = pkgs.fetchurl {
    url = "https://github.com/${v.repo}/releases/download/v${v.version}/plannotator-linux-x64";
    inherit (v) hash;
  };
  pasteBin = pkgs.fetchurl {
    url = "https://github.com/${v.repo}/releases/download/v${v.version}/plannotator-paste-linux-x64";
    hash = v.pasteHash;
  };
in
pkgs.stdenv.mkDerivation {
  pname = "plannotator";
  inherit (v) version;

  dontUnpack = true;
  dontBuild = true;

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [ pkgs.stdenv.cc.cc.lib ];

  installPhase = ''
    mkdir -p $out/bin
    cp ${mainBin} $out/bin/plannotator
    cp ${pasteBin} $out/bin/plannotator-paste
    chmod +x $out/bin/plannotator $out/bin/plannotator-paste
  '';

  meta = {
    description = "Interactive plan review system for AI coding agents";
    homepage = "https://github.com/backnotprop/plannotator";
    license = with lib.licenses; [
      asl20
      mit
    ];
    maintainers = [ ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "plannotator";
  };
}
