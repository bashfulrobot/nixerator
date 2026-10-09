# NixOS plumbing for the kong-docs-rag Claude Code plugin
# (kong-docs-rag@claude-skills), the same plugin the Mac uses. The plugin's
# .mcp.json launches `<repo_path>/bin/kong-docs-rag serve -data-dir
# <repo_path>/data`, so the plugin needs a built checkout of
# github.com/bashfulrobot/kong-docs-rag (private Go repo, no Nix packaging, no
# flake) at the path the manifest declares (`${HOME}/git/kong-docs-rag`).
#
# The activation snippet only provisions the checkout and the binary, the way
# donkeykong's Claudefile documents it for the Mac (clone, `go build`). It
# never pulls an existing checkout and never indexes: the crawl + embed takes
# minutes, needs the network and a running Ollama with nomic-embed-text, and
# `bin/` and `data/` are the user's working state. Failures are non-fatal (the
# clone is a private repo and needs GitHub credentials), same stance as
# cfg/headroom.nix.
#
# Re-indexing is a separate systemd user timer (`systemdUser` below), the
# NixOS counterpart of donkeykong's com.bashfulrobot.kong-docs-rag-reindex
# LaunchAgent (daily 06:00, runs `bin/kong-docs-rag index -data-dir data`).
# Unlike the Mac job it first fast-forwards the checkout and rebuilds when HEAD
# moved, since nothing else on NixOS does that. Every failure path (no binary,
# pull refused, build failed, Ollama down, index error) is logged and exits 0
# so the unit never shows as failed and activation is never affected.
{
  pkgs,
  homeDir,
}:

let
  repo = "${homeDir}/git/kong-docs-rag";

  reindex = pkgs.writeShellScript "kong-docs-rag-reindex" ''
    # No `set -e`: each step is allowed to fail and the script still exits 0.
    export PATH="${
      pkgs.lib.makeBinPath [
        pkgs.git
        pkgs.go
        pkgs.gcc
        pkgs.curl
        pkgs.coreutils
      ]
    }:$PATH"
    # A private repo must fail fast, never wait on a credential prompt.
    export GIT_TERMINAL_PROMPT=0

    repo="${repo}"
    bin="$repo/bin/kong-docs-rag"
    log() { echo "kong-docs-rag-reindex: $*"; }

    if [ ! -x "$bin" ]; then
      log "$bin missing (activation builds it); skipping"
      exit 0
    fi

    before="$(git -C "$repo" rev-parse HEAD 2>/dev/null)"
    if ! git -C "$repo" pull --ff-only; then
      log "git pull --ff-only failed (offline, auth, diverged or dirty tree); keeping current checkout"
    fi
    after="$(git -C "$repo" rev-parse HEAD 2>/dev/null)"

    if [ "$before" != "$after" ]; then
      log "checkout moved ($before -> $after); rebuilding"
      if ! (cd "$repo" && go build -o bin/kong-docs-rag ./cmd/kong-docs-rag); then
        log "go build failed; indexing with the existing binary"
      fi
    fi

    ollama_url="http://127.0.0.1:11434"
    if ! curl -fsS --max-time 5 -o /dev/null "$ollama_url/api/tags"; then
      log "Ollama not reachable at $ollama_url; skipping index until the next run"
      exit 0
    fi

    log "indexing"
    if "$bin" index -data-dir "$repo/data"; then
      log "index finished"
    else
      log "index failed (exit $?); see output above"
    fi
    exit 0
  '';
in
{
  # Merge into home-manager's `systemd.user`, gated by the caller on
  # apps.cli.claude-code.kongDocsRag.enable. The primary user lingers
  # (modules/system/linger), so the timer fires without a login session.
  systemdUser = {
    timers.kong-docs-rag-reindex = {
      Unit.Description = "Daily kong-docs-rag re-index timer";
      Timer = {
        OnCalendar = "*-*-* 06:00:00";
        Persistent = true;
      };
      Install.WantedBy = [ "timers.target" ];
    };

    services.kong-docs-rag-reindex = {
      Unit = {
        Description = "Pull, rebuild if needed, and re-index kong-docs-rag";
        # Skip entirely (not a failure) until the binary exists.
        ConditionPathExists = "${repo}/bin/kong-docs-rag";
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${reindex}";
        TimeoutStartSec = "1h";
      };
    };
  };

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
