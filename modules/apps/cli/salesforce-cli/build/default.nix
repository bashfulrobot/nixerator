{
  lib,
  pkgs,
  versions,
  ...
}:
let
  v = versions.cli.salesforce-cli;
in
pkgs.stdenv.mkDerivation {
  pname = "salesforce-cli";
  inherit (v) version;

  src = pkgs.fetchurl {
    url = "https://github.com/salesforcecli/cli/releases/download/${v.version}/sf-v${v.version}-${v.shortRev}-linux-x64.tar.xz";
    inherit (v) hash;
  };

  nativeBuildInputs = with pkgs; [
    autoPatchelfHook
  ];

  buildInputs = with pkgs; [
    stdenv.cc.cc.lib
  ];

  dontBuild = true;

  sourceRoot = "sf";

  installPhase = ''
    mkdir -p $out/bin $out/lib/sf
    cp -r . $out/lib/sf/
    ln -s $out/lib/sf/bin/sf $out/bin/sf
    ln -s $out/lib/sf/bin/sf $out/bin/sfdx
  '';

  meta = with lib; {
    description = "Salesforce CLI — develop, customize, test, and deploy on the Salesforce Platform";
    homepage = "https://developer.salesforce.com/tools/salesforcecli";
    license = licenses.bsd3;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
}
