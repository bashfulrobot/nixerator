# NixOS plumbing for the kong-docs-rag Claude Code plugin
# (kong-docs-rag@claude-skills), the same plugin the Mac uses. The plugin's
# .mcp.json launches `<repo_path>/bin/kong-docs-rag serve -data-dir
# <repo_path>/data`, so the plugin needs a built checkout of
# github.com/bashfulrobot/kong-docs-rag (private Go repo, no Nix packaging, no
# flake) at the path the manifest declares (`${HOME}/git/kong-docs-rag`).
#
# This only provisions the checkout and the binary, the way donkeykong's
# Claudefile documents it for the Mac (clone, `go build`). It never pulls an
# existing checkout and never indexes: the crawl + embed takes minutes, needs
# the network and a running Ollama with nomic-embed-text, and `bin/` and
# `data/` are the user's working state. Failures are non-fatal (the clone is
# a private repo and needs GitHub credentials), same stance as cfg/headroom.nix.
{
  pkgs,
  homeDir,
}:

let
  repo = "${homeDir}/git/kong-docs-rag";
in
{
  activation = ''
    if [ -z "$DRY_RUN_CMD" ]; then
      kdr_repo="${repo}"
      if [ ! -d "$kdr_repo/.git" ]; then
        mkdir -p "$(dirname "$kdr_repo")"
        ${pkgs.git}/bin/git clone https://github.com/bashfulrobot/kong-docs-rag.git "$kdr_repo" \
          || echo "kong-docs-rag: clone failed (private repo; needs GitHub auth). Clone it to $kdr_repo by hand." >&2
      fi
      if [ -d "$kdr_repo/.git" ] && [ ! -x "$kdr_repo/bin/kong-docs-rag" ]; then
        (cd "$kdr_repo" && PATH="${pkgs.git}/bin:${pkgs.gcc}/bin:$PATH" ${pkgs.go}/bin/go build -o bin/kong-docs-rag ./cmd/kong-docs-rag) \
          || echo "kong-docs-rag: go build failed (see output above); build it by hand in $kdr_repo" >&2
      fi
    fi
  '';
}
