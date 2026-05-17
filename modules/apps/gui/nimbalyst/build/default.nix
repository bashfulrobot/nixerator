# Local package for Nimbalyst — visual editor for Claude Code & Codex
# Version managed in settings/versions.nix

{
  lib,
  fetchurl,
  appimageTools,
  versions,
}:
let
  pname = "nimbalyst";
  v = versions.gui.nimbalyst;
  inherit (v) version;

  src = fetchurl {
    url = "https://github.com/Nimbalyst/nimbalyst/releases/download/v${version}/Nimbalyst-Linux.AppImage";
    inherit (v) hash;
  };

  meta = {
    homepage = "https://nimbalyst.com";
    description = "Visual editor and session manager for Claude Code, Codex, Opencode, and Copilot";
    mainProgram = "nimbalyst";
    changelog = "https://github.com/Nimbalyst/nimbalyst/releases/tag/v${version}";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    maintainers = [ ];
  };
in
appimageTools.wrapType2 {
  inherit
    pname
    version
    src
    meta
    ;

  extraInstallCommands =
    let
      appimageContents = appimageTools.extract {
        inherit pname version src;
      };
    in
    ''
      install -Dm444 ${appimageContents}/@nimbalystelectron.desktop \
        $out/share/applications/nimbalyst.desktop
      install -Dm444 ${appimageContents}/@nimbalystelectron.png \
        $out/share/pixmaps/nimbalyst.png

      # Rewrite AppRun → wrapped binary name and the @-prefixed icon name.
      # Upstream desktop file ships a single `Exec=AppRun --no-sandbox %U`
      # line, so one substitution is enough; a second `--replace-fail` on
      # bare `Exec=AppRun` would abort after the first rewrite consumed it.
      substituteInPlace $out/share/applications/nimbalyst.desktop \
        --replace-fail 'Exec=AppRun --no-sandbox %U' 'Exec=nimbalyst --no-sandbox %U' \
        --replace-fail 'Icon=@nimbalystelectron' 'Icon=nimbalyst'
    '';
}
