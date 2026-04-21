{
  lib,
  pkgs,
  versions,
  ...
}:
pkgs.stdenv.mkDerivation {
  name = "clawide";
  src = pkgs.fetchurl {
    url = "https://github.com/davydany/ClawIDE/releases/download/v${versions.cli.claw-ide.version}/clawide-v${versions.cli.claw-ide.version}-linux-amd64.tar.gz";
    inherit (versions.cli.claw-ide) hash;
  };

  nativeBuildInputs = [ pkgs.autoPatchelfHook ];
  buildInputs = [
    pkgs.stdenv.cc.cc.lib
  ];

  dontBuild = true;

  installPhase = ''
    mkdir -p $out/bin
    cp clawide $out/bin/clawide
    chmod +x $out/bin/clawide
  '';

  meta = with lib; {
    description = "Web-based IDE for Claude Code - https://github.com/davydany/ClawIDE";
    homepage = "https://github.com/davydany/ClawIDE";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "clawide";
    maintainers = [ ];
  };
}
