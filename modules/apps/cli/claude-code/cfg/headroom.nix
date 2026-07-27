# NixOS plumbing for Headroom (headroomlabs-ai/headroom, PyPI package
# `headroom-ai`), a local context-compression layer for coding agents:
# `headroom wrap claude` (and codex/grok/copilot/...) proxies a session
# through local compressors before tokens reach the model.
#
# Not a Claude Code plugin -- there is no marketplace entry, and the tool
# isn't Claude-specific. It ships only as a PyPI package whose `[all]` extra
# pulls in heavy optional ML dependencies (the local Kompress-v2-base
# compressor, sentence-transformers, torch), which is exactly the kind of
# dependency graph that's fragile to hand-build with buildPythonApplication
# and disproportionate for a single CLI tool. Installed imperatively at Home
# Manager activation via `uv tool install`, the same install command
# upstream's own README documents. `uv` itself is a plain nixpkgs package, so
# only headroom's own venv (and its transitive PyPI deps) is unpinned by the
# Nix store -- the installer is still reproducible.
{
  pkgs,
  versions,
  homeDir,
}:

let
  inherit (versions.cli.headroom) package version;

  # Stamped with the requested version after a successful install. Activation
  # only re-runs `uv tool install` when this doesn't match versions.nix, so a
  # `home-manager switch` that changed nothing about headroom doesn't pay for
  # dependency resolution (network + several hundred MB of ML extras) on
  # every rebuild.
  installMarker = "${homeDir}/.local/share/headroom/.nix-installed-version";
in
{
  activation = ''
    headroom_marker="${installMarker}"
    if [ -z "$DRY_RUN_CMD" ]; then
      mkdir -p "$(dirname "$headroom_marker")"
      installed_version=""
      if [ -f "$headroom_marker" ]; then
        installed_version="$(cat "$headroom_marker" 2>/dev/null || true)"
      fi
      if [ "$installed_version" != "${version}" ]; then
        if ${pkgs.uv}/bin/uv tool install --python 3.13 --force "${package}[all]==${version}"; then
          printf '%s' "${version}" > "$headroom_marker"
        else
          echo "headroom: uv tool install failed (see output above); leaving previous install in place" >&2
        fi
      fi
    fi
  '';
}
