# Local package for Orca (stablyai/orca) -- agent development environment
# Version managed in settings/versions.nix
#
# Upstream ships an AppImage, a deb and an rpm; nixpkgs has no package
# (nixpkgs `orca` is the GNOME screen reader). The AppImage asset name is
# unversioned, so the pinned hash is tied to the release tag.

{
  lib,
  fetchurl,
  appimageTools,
  versions,
}:
let
  pname = "orca";
  v = versions.gui.orca;
  inherit (v) version;

  src = fetchurl {
    url = "https://github.com/stablyai/orca/releases/download/v${version}/orca-linux.AppImage";
    inherit (v) hash;
  };

  meta = {
    homepage = "https://orca.dev";
    description = "Agent development environment: run Claude Code, Codex and other coding agents in parallel git worktrees";
    mainProgram = "orca";
    changelog = "https://github.com/stablyai/orca/releases/tag/v${version}";
    license = lib.licenses.mit;
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
}
