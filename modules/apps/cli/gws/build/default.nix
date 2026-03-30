{
  lib,
  pkgs,
  versions,
  ...
}:
pkgs.stdenv.mkDerivation {
  name = "gws";
  src = pkgs.fetchurl {
    url = "https://github.com/googleworkspace/cli/releases/download/v${versions.cli.gws.version}/google-workspace-cli-x86_64-unknown-linux-gnu.tar.gz";
    inherit (versions.cli.gws) hash;
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [
    pkgs.stdenv.cc.cc.lib
  ];

  dontBuild = true;

  sourceRoot = "google-workspace-cli-x86_64-unknown-linux-gnu";

  installPhase = ''
    mkdir -p $out/bin
    cp gws $out/bin/gws
    chmod +x $out/bin/gws
  '';

  meta = with lib; {
    description = "Google Workspace CLI — one command-line tool for Drive, Gmail, Calendar, Sheets, Docs, Chat, Admin, and more - https://github.com/googleworkspace/cli";
    maintainers = [ ];
  };
}
