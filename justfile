# NixOS Configuration Management
# https://github.com/casey/just

# === Settings ===
set dotenv-load := true
set ignore-comments := true
set fallback := true
set shell := ["bash", "-euo", "pipefail", "-c"]

mod ref 'extras/ref.just'
mod setup 'extras/setup.just'

# === Variables ===
hostname := `hostname`
host_flake := ".#" + hostname
timestamp := `date +%Y-%m-%d_%H-%M-%S`

# === Help ===
# Show available recipes
default:
    @just --list --unsorted

# === Core Recipes ===
# Production rebuild of the current host
rebuild:
    #!/usr/bin/env bash
    set -uo pipefail
    # If the caller already gave us a rendered path (e.g. remote-rebuild
    # scp'd one into /run/user/$UID), use it verbatim and don't shred —
    # the caller owns its lifecycle. Otherwise render now.
    if [[ -z "${NIXERATOR_SECRETS:-}" ]]; then
        if ! rendered=$(just _render-secrets); then
            echo "error: secrets render failed; aborting rebuild." >&2
            exit 1
        fi
        if [[ -z "$rendered" || ! -s "$rendered" ]]; then
            echo "error: render produced empty/missing file; aborting rebuild." >&2
            exit 1
        fi
        trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"' EXIT
        export NIXERATOR_SECRETS="$rendered"
    fi
    just pre-rebuild interactive
    log="{{rebuild_log}}"
    rc=0
    gum spin --spinner dot --title "Rebuilding NixOS configuration..." \
        -- bash -c 'sudo --preserve-env=NIXERATOR_SECRETS nixos-rebuild switch --impure --flake {{host_flake}} &> "'"$log"'"' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        warnings=$(grep -c -E -i 'warning:' "$log" 2>/dev/null || true)
        if [[ "$warnings" -gt 0 ]]; then
            gum style --foreground 220 "Rebuild succeeded with $warnings warning(s)"
            if gum confirm "View warnings in log?"; then
                bat --paging=always "$log"
            fi
        else
            gum style --foreground 82 "Rebuild succeeded"
        fi
        just post-rebuild interactive

        # Run package update check in background, show results when done
        echo ""
        bash extras/scripts/check-pkg-updates.bash 2>/dev/null || true
        echo ""
        bash extras/scripts/check-security-alerts.bash 2>/dev/null || true
    else
        gum style --foreground 196 "Rebuild FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi

# Stage all, rebuild, unstage on exit
dev-rebuild:
    #!/usr/bin/env bash
    set -uo pipefail
    gum style --foreground 245 "Staging all changes..."
    git add -A
    trap 'git restore --staged .' EXIT
    just rebuild

# Full system upgrade
upgrade:
    #!/usr/bin/env bash
    set -uo pipefail
    # See `rebuild` for the conditional-render rationale.
    if [[ -z "${NIXERATOR_SECRETS:-}" ]]; then
        if ! rendered=$(just _render-secrets); then
            echo "error: secrets render failed; aborting upgrade." >&2
            exit 1
        fi
        if [[ -z "$rendered" || ! -s "$rendered" ]]; then
            echo "error: render produced empty/missing file; aborting upgrade." >&2
            exit 1
        fi
        trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"' EXIT
        export NIXERATOR_SECRETS="$rendered"
    fi
    just pre-rebuild interactive
    log="{{upgrade_log}}"
    cp flake.lock flake.lock-backup-{{timestamp}}
    rc=0
    gum spin --spinner dot --title "Updating flake inputs..." \
        -- bash -c 'nix flake update &> "'"$log"'"' || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        gum style --foreground 196 "Flake update FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi
    gum style --foreground 82 "Flake inputs updated"
    gum spin --spinner dot --title "Rebuilding with upgrades..." \
        -- bash -c 'sudo --preserve-env=NIXERATOR_SECRETS nixos-rebuild switch --impure --upgrade --flake {{host_flake}} &>> "'"$log"'"' || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        gum style --foreground 196 "Rebuild FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi
    gum style --foreground 82 "System rebuilt"
    gum spin --spinner dot --title "Setting up voxtype..." \
        -- bash -c 'just ref::voxtype-setup &>> "'"$log"'"' || rc=$?
    if [[ "$rc" -ne 0 ]]; then
        gum style --foreground 196 "Voxtype setup FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi
    gum style --foreground 82 "Voxtype configured"
    warnings=$(grep -c -E -i 'warning:' "$log" 2>/dev/null || true)
    if [[ "$warnings" -gt 0 ]]; then
        gum style --foreground 220 "Upgrade completed with $warnings warning(s)"
        if gum confirm "View warnings in log?"; then
            bat --paging=always "$log"
        fi
    else
        gum style --foreground 82 "Upgrade complete"
    fi
    just post-rebuild interactive

    # Run package update check after successful upgrade
    echo ""
    bash extras/scripts/check-pkg-updates.bash 2>/dev/null || true
    echo ""
    bash extras/scripts/check-security-alerts.bash 2>/dev/null || true

# Update a specific flake input
update input:
    @echo "Updating {{input}}..."
    @nix flake update {{input}}

# Show open Dependabot alerts and what changed since the last check
check-security:
    @bash extras/scripts/check-security-alerts.bash

# Garbage collection (default: 5 days)
clean days="5":
    @echo "Cleaning packages older than {{days}} days..."
    @sudo nix-collect-garbage --delete-older-than {{days}}d

# Nuclear garbage collection — maximum cleanup
gc-nuclear:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "NUCLEAR GARBAGE COLLECTION"
    echo "================================"
    echo "Deleting old system generations..."
    sudo nix-env --delete-generations old --profile /nix/var/nix/profiles/system
    echo ""
    echo "Deleting old boot generations..."
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
    echo ""
    echo "Running full garbage collection..."
    sudo nix-collect-garbage -d
    echo ""
    echo "Clearing nix evaluation cache..."
    rm -rf ~/.cache/nix
    echo ""
    echo "Optimizing nix store (this may take a while)..."
    nix-store --optimize
    echo ""
    echo "Nuclear cleanup complete!"
    echo "Disk space reclaimed:"
    df -h / | tail -1

# Smart push/pull — detects git state and acts accordingly
sync-git:
    #!/usr/bin/env bash
    set -euo pipefail

    current_branch=$(git rev-parse --abbrev-ref HEAD)

    # Pause syncthing during git operations
    systemctl --user stop syncthing || true
    trap 'systemctl --user start syncthing || true' EXIT

    git fetch origin

    local_only=$(git log "origin/$current_branch..$current_branch" --oneline 2>/dev/null || true)
    remote_only=$(git log "$current_branch..origin/$current_branch" --oneline 2>/dev/null || true)

    if [[ -n "$local_only" && -n "$remote_only" ]]; then
        echo "Diverged — local and remote both have commits:"
        echo ""
        echo "Local:"
        echo "$local_only"
        echo ""
        echo "Remote:"
        echo "$remote_only"
        echo ""
        echo "Resolve manually (rebase, merge, or force-push)."
        exit 1

    elif [[ -n "$local_only" ]]; then
        echo "Pushing unpushed commits..."
        git push origin "$current_branch"
        echo "Pushed to origin/$current_branch"

    elif [[ -n "$remote_only" ]]; then
        echo "Aligning git state with remote..."
        git reset --hard "origin/$current_branch"
        git clean -fd
        echo "Git state aligned with origin/$current_branch"

    else
        echo "Already in sync with origin/$current_branch"
    fi

    git status --short

# Check code health with deadnix and statix
health:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Running code health checks..."
    echo ""
    echo "Checking for unused code with deadnix..."
    deadnix .
    echo ""
    echo "Running statix linter..."
    fd -e nix --hidden --no-ignore --follow . -x statix check {}
    echo ""
    echo "Code health check complete"

# Format all nix files
fmt:
    @echo "Formatting nix files..."
    @nix fmt

# Update manually-installed Claude skills from GitHub
#
# Runs skillfish for its tracked skills, then bumps any flake-pinned
# upstream skills (currently just `humanizer-skill` -> blader/humanizer).
# Skills authored in this repo under config/skills/ are managed by
# claude-capture and need no separate update step.
update-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v skillfish >/dev/null 2>&1; then
        echo "Updating skillfish-managed skills..."
        skillfish update --yes || echo "skillfish update failed (non-fatal)"
    fi
    echo "Bumping flake-pinned upstream skills..."
    nix flake update humanizer-skill || echo "humanizer-skill update failed (non-fatal)"
    echo "Skills updated"

# Ad-hoc capture of live ~/.claude and ~/agent-os state into the repo.
#
# Auto-capture during rebuild is gated to qbert (the designated source of
# truth) so non-canonical hosts don't regress the repo. Use this recipe to
# manually surface a new skill/agent/setting installed on any other host
# (donkeykong, etc.) -- review the resulting diff and commit only the bits
# that should propagate.
capture:
    #!/usr/bin/env bash
    set -uo pipefail
    echo "Capturing Claude Code config..."
    fish -c 'claude-capture' || echo "Claude capture failed (non-fatal)"
    echo "Capturing Agent OS config..."
    fish -c 'agentos-capture' || echo "Agent OS capture failed (non-fatal)"
    echo ""
    echo "Review with: git status && git diff modules/apps/cli/claude-code modules/apps/cli/agentos"

# === Shared Helpers ===
rebuild_log := "/tmp/nixerator-rebuild.log"
upgrade_log := "/tmp/nixerator-upgrade.log"

# Render a secrets JSON into a short-lived tmpfs file (mode 600,
# /run/user/$UID). Prints the path on stdout for callers to capture, export
# as NIXERATOR_SECRETS, and trap-cleanup with `shred`.
#
# Dual-mode while the 1Password migration is in flight (issue #61):
#  1. Preferred: render secrets/secrets.json.tpl via `op inject` (auto-
#     prompts `op signin` if needed). This is the 1Password path.
#  2. Fallback: copy the git-crypt-decrypted secrets/secrets.json verbatim.
#     Lets `just rebuild` keep working on hosts that haven't migrated yet.
#
# The caller always shreds the returned path, so this recipe never returns
# a path inside the repo — both modes write to tmpfs.
[private]
_render-secrets:
    #!/usr/bin/env bash
    set -euo pipefail

    # The rendered file holds plaintext secrets, so it must land on tmpfs
    # so `shred -u` is meaningful (CoW/journalled filesystems retain old
    # blocks). `/run/user/$UID` is tmpfs on every NixOS host with logind;
    # fail loudly rather than silently downgrade to a persistent path.
    runtime_dir="/run/user/$(id -u)"
    if [[ ! -d "$runtime_dir" ]]; then
        echo "error: $runtime_dir does not exist; logind / XDG_RUNTIME_DIR not set up." >&2
        echo "       refusing to render secrets to a non-tmpfs path." >&2
        exit 1
    fi
    if ! findmnt -T "$runtime_dir" -no FSTYPE 2>/dev/null | grep -qx tmpfs; then
        echo "error: $runtime_dir is not on tmpfs; refusing to render secrets." >&2
        exit 1
    fi

    rendered=$(mktemp -p "$runtime_dir" nixerator-XXXXXX.json)
    chmod 600 "$rendered"
    # Make sure a render-side failure cleans up the half-baked file.
    trap 'rm -f "$rendered"' ERR

    # Path 1: 1Password (preferred). Requires `op` available, signed in,
    # and every op:// reference in the template to resolve. Diagnostics
    # from `op signin` / `op inject` are forwarded to stderr so the user
    # can see why the 1P path failed (missing item, renamed field, etc.)
    # before the fallback engages.
    if command -v op >/dev/null 2>&1 \
        && [[ -f secrets/secrets.json.tpl ]] \
        && { op whoami >/dev/null 2>&1 || eval "$(op signin)"; } \
        && op whoami >/dev/null 2>&1 \
        && op inject -i secrets/secrets.json.tpl -o "$rendered"; then
        trap - ERR
        echo "$rendered"
        exit 0
    fi

    # Path 2: git-crypt fallback. `secrets/secrets.json` is either
    # encrypted (binary, starts with `\0GITCRYPT`) or plaintext JSON.
    # `jq -e .` parses iff it's well-formed JSON, which both detects
    # the plaintext-vs-encrypted case AND rejects garbage that
    # happened to start with `{` (a leading-byte heuristic doesn't).
    if [[ -f secrets/secrets.json ]] && jq -e . secrets/secrets.json >/dev/null 2>&1; then
        cp secrets/secrets.json "$rendered"
        trap - ERR
        echo "$rendered"
        exit 0
    fi

    rm -f "$rendered"
    trap - ERR
    echo 'error: no 1Password session and no decrypted secrets/secrets.json available' >&2
    echo 'fix: run `eval "$(op signin)"` (after populating 1P), or unlock git-crypt.' >&2
    exit 1

# Pre-rebuild: capture runtime ~/.claude/* edits back into the source tree
# before activation overwrites them with the previously-captured version.
# Without this, any change made directly to a managed file (CLAUDE.md,
# settings.json, agents, skills, output-styles, plugin metadata) between
# rebuilds is silently lost when the activation script runs.
# mode: "interactive" (gum spin) or "quiet" (plain echo)
[private]
pre-rebuild mode="quiet":
    #!/usr/bin/env bash
    set -uo pipefail
    # Capture flows live ~/.claude state into the repo. Only qbert is the
    # designated capture source -- other hosts (donkeykong, srv, ...) carry
    # narrower live state and would silently regress the repo if allowed to
    # auto-capture. For ad-hoc captures from another host (e.g. a newly
    # installed skill), run `just capture` explicitly.
    case "$(hostname)" in
        qbert) ;;
        *) exit 0 ;;
    esac
    if [[ "{{mode}}" == "interactive" ]]; then
        gum spin --spinner dot --title "Capturing live Claude Code config (pre-rebuild)..." \
            -- bash -c 'fish -c "claude-capture" &>/dev/null' || gum style --foreground 220 "Pre-capture failed (non-fatal)"
        gum spin --spinner dot --title "Capturing live Agent OS config (pre-rebuild)..." \
            -- bash -c 'fish -c "agentos-capture" &>/dev/null' || gum style --foreground 220 "Agent OS pre-capture failed (non-fatal)"
    else
        echo "Capturing live Claude Code config (pre-rebuild)..."
        fish -c 'claude-capture' &>/dev/null || echo "Pre-capture failed (non-fatal)"
        echo "Capturing live Agent OS config (pre-rebuild)..."
        fish -c 'agentos-capture' &>/dev/null || echo "Agent OS pre-capture failed (non-fatal)"
    fi

# Post-rebuild: sync plugins, capture config, check for changes
# mode: "interactive" (gum spin) or "quiet" (plain echo)
[private]
post-rebuild mode="quiet":
    #!/usr/bin/env bash
    set -uo pipefail
    # Sync/skills-update flow repo -> live (safe on every host).
    # Capture flows live -> repo; only qbert is the designated capture source.
    # For ad-hoc captures from another host, run `just capture` explicitly.
    is_capture_source=false
    case "$(hostname)" in
        qbert) is_capture_source=true ;;
    esac
    if [[ "{{mode}}" == "interactive" ]]; then
        gum spin --spinner dot --title "Syncing plugins..." \
            -- bash -c 'claude-sync-plugins &>/dev/null' || gum style --foreground 220 "Plugin sync failed (non-fatal)"
        gum spin --spinner dot --title "Updating skills..." \
            -- bash -c 'just update-skills &>/dev/null' || gum style --foreground 220 "Skill update failed (non-fatal)"
        if $is_capture_source; then
            gum spin --spinner dot --title "Capturing Claude Code config..." \
                -- bash -c 'fish -c "claude-capture" &>/dev/null' || gum style --foreground 220 "Capture failed (non-fatal)"
            gum spin --spinner dot --title "Capturing Agent OS config..." \
                -- bash -c 'fish -c "agentos-capture" &>/dev/null' || gum style --foreground 220 "Agent OS capture failed (non-fatal)"
        fi
    else
        echo "Syncing plugins..."
        claude-sync-plugins || echo "Plugin sync failed (non-fatal)"
        echo "Updating skills..."
        just update-skills || echo "Skill update failed (non-fatal)"
        if $is_capture_source; then
            echo "Capturing Claude Code config..."
            fish -c 'claude-capture' || echo "Capture failed (non-fatal)"
            echo "Capturing Agent OS config..."
            fish -c 'agentos-capture' || echo "Agent OS capture failed (non-fatal)"
        fi
    fi

    if $is_capture_source && ! git diff --quiet modules/apps/cli/claude-code/config/plugins/ 2>/dev/null; then
        commit_msg='fix(claude-code): update captured plugin state'
        echo ""
        if [[ "{{mode}}" == "interactive" ]]; then
            gum style --foreground 220 --bold "Plugin config changed! Commit with:"
        else
            echo "════════════════════════════════════════════════════════════"
            echo "  Plugin config changed! Commit with:"
        fi
        echo "  git add modules/apps/cli/claude-code/config/plugins/ && git commit -m \"$commit_msg\""
        if [[ "{{mode}}" != "interactive" ]]; then
            echo "════════════════════════════════════════════════════════════"
        fi
        echo "$commit_msg" | wl-copy 2>/dev/null || true
        notify-send "Nixerator" "Plugin config changed — commit suggested" 2>/dev/null || true
    fi

# === Quiet Recipes ===

# Quiet rebuild -- captures output, shows only errors on failure
quiet-rebuild:
    #!/usr/bin/env bash
    set -uo pipefail

    # Pre-rebuild guard: warn about uncommitted plugin changes
    if ! git diff --quiet modules/apps/cli/claude-code/config/plugins/ 2>/dev/null; then
        echo "⚠ Uncommitted plugin changes from a previous sync. Commit or discard before rebuilding."
    fi

    # remote-rebuild scp's a rendered file and sets NIXERATOR_SECRETS over
    # SSH — re-rendering here would clobber it (and require an op signin
    # on the remote, which can't TTY-prompt). Honor the inherited value.
    if [[ -z "${NIXERATOR_SECRETS:-}" ]]; then
        if ! rendered=$(just _render-secrets); then
            echo "error: secrets render failed; aborting rebuild." >&2
            exit 1
        fi
        if [[ -z "$rendered" || ! -s "$rendered" ]]; then
            echo "error: render produced empty/missing file; aborting rebuild." >&2
            exit 1
        fi
        # Install the cleanup trap immediately so a signal/abort between
        # here and the build can't leak the tmpfs file.
        trap 'git restore --staged . 2>/dev/null || true; shred -u "$rendered" 2>/dev/null || rm -f "$rendered"' EXIT
        export NIXERATOR_SECRETS="$rendered"
    else
        # Caller supplied the path; only restore the staging area on exit.
        trap 'git restore --staged . 2>/dev/null || true' EXIT
    fi

    just pre-rebuild quiet

    echo "Rebuilding (quiet mode)..."
    git add -A
    rc=0
    sudo --preserve-env=NIXERATOR_SECRETS nixos-rebuild switch --impure --flake {{host_flake}} &> {{rebuild_log}} || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Rebuild succeeded. Full log: {{rebuild_log}}"

        just post-rebuild quiet
    else
        filtered=$(grep -E -i '(^error|error:|warning:|trace:|fatal|failed to)' {{rebuild_log}} | head -80)
        {
            echo "=== FILTERED ERRORS/WARNINGS ==="
            echo "$filtered"
            echo ""
            echo "=== FULL BUILD LOG ==="
            cat {{rebuild_log}}
        } > {{rebuild_log}}.tmp
        mv {{rebuild_log}}.tmp {{rebuild_log}}
        echo "Rebuild FAILED (exit $rc). Use a Nix subagent to diagnose {{rebuild_log}} and fix the issue."
        exit "$rc"
    fi

# Quiet upgrade -- captures output, shows only errors on failure
quiet-upgrade:
    #!/usr/bin/env bash
    set -uo pipefail
    # See `quiet-rebuild` for the conditional-render rationale.
    if [[ -z "${NIXERATOR_SECRETS:-}" ]]; then
        if ! rendered=$(just _render-secrets); then
            echo "error: secrets render failed; aborting upgrade." >&2
            exit 1
        fi
        if [[ -z "$rendered" || ! -s "$rendered" ]]; then
            echo "error: render produced empty/missing file; aborting upgrade." >&2
            exit 1
        fi
        trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"' EXIT
        export NIXERATOR_SECRETS="$rendered"
    fi
    just pre-rebuild quiet
    echo "Upgrading (quiet mode)..."
    cp flake.lock flake.lock-backup-{{timestamp}}
    rc=0
    {
        nix flake update
        sudo --preserve-env=NIXERATOR_SECRETS nixos-rebuild switch --impure --upgrade --flake {{host_flake}}
        just ref::voxtype-setup
    } &> {{upgrade_log}} || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Upgrade succeeded. Full log: {{upgrade_log}}"

        just post-rebuild quiet
    else
        filtered=$(grep -E -i '(^error|error:|warning:|trace:|fatal|failed to)' {{upgrade_log}} | head -80)
        {
            echo "=== FILTERED ERRORS/WARNINGS ==="
            echo "$filtered"
            echo ""
            echo "=== FULL BUILD LOG ==="
            cat {{upgrade_log}}
        } > {{upgrade_log}}.tmp
        mv {{upgrade_log}}.tmp {{upgrade_log}}
        echo "Upgrade FAILED (exit $rc). Use a Nix subagent to diagnose {{upgrade_log}} and fix the issue."
        exit "$rc"
    fi

# Remote rebuild — pull and rebuild on another nixerator host over SSH.
#
# Workflow: commit + push from this machine, then `just remote-rebuild qbert`.
# The remote SSHes back to GitHub via your forwarded ssh-agent (requires the
# host to have forwardAgent=true in modules/system/ssh/default.nix), pulls
# fast-forward only, then runs `just qr` of its own host configuration.
remote-rebuild host repo_path="~/git/nixerator":
    #!/usr/bin/env bash
    set -uo pipefail
    # Allowlist: the only valid hosts are the three nixerator boxes.
    # Without this, an attacker-influenced `host` arg starting with `-`
    # would be parsed as an ssh/scp option (e.g. -oProxyCommand=).
    case "{{host}}" in
        qbert|donkeykong|srv) ;;
        *)
            echo "error: unrecognized host: {{host}} (allowed: qbert, donkeykong, srv)" >&2
            exit 2
            ;;
    esac
    host="{{host}}"
    echo "Rebuilding $host via SSH..."
    rendered=$(just _render-secrets)
    # Create the remote tmpfs file via mktemp on the remote side so the
    # name is unpredictable. A `nixerator-remote-$$.json` naming scheme
    # would let any same-UID process on the remote pre-create a symlink
    # at that path and redirect the scp'd plaintext.
    remote_path=$(ssh -o BatchMode=yes "$host" 'mktemp -p "/run/user/$(id -u)" nixerator-remote-XXXXXX.json')
    trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"; ssh -o BatchMode=yes "'"$host"'" "rm -f '"$remote_path"'" 2>/dev/null || true' EXIT
    scp -pq -o BatchMode=yes "$rendered" "$host:$remote_path"
    rc=0
    ssh -A -o BatchMode=yes -o ConnectTimeout=5 "$host" \
        "cd {{repo_path}} && git pull --ff-only && NIXERATOR_SECRETS=$remote_path just qr" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Remote rebuild on $host succeeded."
    else
        echo "Remote rebuild on $host FAILED (exit $rc)."
        exit "$rc"
    fi

# Remote upgrade — pull and full upgrade (flake update + rebuild) on another
# nixerator host over SSH. Same prereqs as `remote-rebuild`. Heavier than
# `rr` because the remote runs `nix flake update` before rebuilding.
remote-upgrade host repo_path="~/git/nixerator":
    #!/usr/bin/env bash
    set -uo pipefail
    # See `remote-rebuild` for the host allowlist rationale.
    case "{{host}}" in
        qbert|donkeykong|srv) ;;
        *)
            echo "error: unrecognized host: {{host}} (allowed: qbert, donkeykong, srv)" >&2
            exit 2
            ;;
    esac
    host="{{host}}"
    echo "Upgrading $host via SSH..."
    rendered=$(just _render-secrets)
    remote_path=$(ssh -o BatchMode=yes "$host" 'mktemp -p "/run/user/$(id -u)" nixerator-remote-XXXXXX.json')
    trap 'shred -u "$rendered" 2>/dev/null || rm -f "$rendered"; ssh -o BatchMode=yes "'"$host"'" "rm -f '"$remote_path"'" 2>/dev/null || true' EXIT
    scp -pq -o BatchMode=yes "$rendered" "$host:$remote_path"
    rc=0
    ssh -A -o BatchMode=yes -o ConnectTimeout=5 "$host" \
        "cd {{repo_path}} && git pull --ff-only && NIXERATOR_SECRETS=$remote_path just qu" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Remote upgrade on $host succeeded."
    else
        echo "Remote upgrade on $host FAILED (exit $rc)."
        exit "$rc"
    fi

# === Aliases ===
alias r := rebuild
alias up := upgrade
alias gc := clean
alias qr := quiet-rebuild
alias qu := quiet-upgrade
alias rr := remote-rebuild
alias ru := remote-upgrade
