{
  lib,
  pkgs,
  versions,
  ...
}:

let
  v = versions.cli.gurk;
in
pkgs.stdenv.mkDerivation {
  name = "gurk";

  src = pkgs.fetchurl {
    url = "https://github.com/boxdot/gurk-rs/releases/download/v${v.version}/gurk-x86_64-unknown-linux-gnu.tar.gz";
    inherit (v) hash;
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];

  buildInputs = [
    pkgs.stdenv.cc.cc.lib
    pkgs.openssl
  ];

  sourceRoot = ".";
  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp gurk $out/bin/gurk
    chmod +x $out/bin/gurk
  '';

  meta = with lib; {
    description = "Signal Messenger client for terminal - https://github.com/boxdot/gurk-rs";
    homepage = "https://github.com/boxdot/gurk-rs";
    license = licenses.agpl3Only;
    platforms = [ "x86_64-linux" ];
    mainProgram = "gurk";
    maintainers = [ ];
  };
}
