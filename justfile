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
    just pre-rebuild interactive
    log="{{rebuild_log}}"
    rc=0
    gum spin --spinner dot --title "Rebuilding NixOS configuration..." \
        -- bash -c 'sudo nixos-rebuild switch --impure --flake {{host_flake}} &> "'"$log"'"' || rc=$?
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
        -- bash -c 'sudo nixos-rebuild switch --impure --upgrade --flake {{host_flake}} &>> "'"$log"'"' || rc=$?
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

# Run skill-cache unit tests
test-skill-cache:
    nix shell nixpkgs#bats nixpkgs#jq --command bats modules/apps/cli/skill-cache/tests/

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

# List system generations (with current marker)
generations:
    @sudo nix-env --profile /nix/var/nix/profiles/system --list-generations

# Roll back to a previous system generation. No arg = one step back
# (`nixos-rebuild --rollback`). With arg = jump to that specific gen
# (e.g. `just rollback 721`). Asks for confirmation before switching
# because this is destructive to the current generation pointer.
rollback gen="":
    #!/usr/bin/env bash
    set -uo pipefail
    sudo nix-env --profile /nix/var/nix/profiles/system --list-generations | tail -8
    echo ""
    target="{{gen}}"
    if [[ -z "$target" ]]; then
        prompt="Roll back ONE generation (sudo nixos-rebuild --rollback switch)?"
    else
        if [[ ! -L "/nix/var/nix/profiles/system-${target}-link" ]]; then
            echo "Generation ${target} not found at /nix/var/nix/profiles/system-${target}-link" >&2
            exit 1
        fi
        prompt="Switch to generation ${target}?"
    fi
    if ! gum confirm "$prompt"; then
        echo "Cancelled."
        exit 0
    fi
    if [[ -z "$target" ]]; then
        sudo nixos-rebuild --rollback switch
    else
        sudo "/nix/var/nix/profiles/system-${target}-link/bin/switch-to-configuration" switch
    fi
    echo ""
    echo "Active generation now:"
    sudo nix-env --profile /nix/var/nix/profiles/system --list-generations | grep "(current)"

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

# Install repo git hooks (sets core.hooksPath to .githooks for this clone)
#
# The pre-commit hook auto-formats staged .nix files via `nix fmt` so no
# commit can introduce formatting drift, regardless of editor/agent/human.
# Run once per clone.
setup-hooks:
    @git config core.hooksPath .githooks
    @echo "git hooks installed: core.hooksPath -> .githooks"

# Update manually-installed Claude skills from GitHub
#
# Applies skillfish-tracked updates and reports what changed via
# claude-skill-updates (which also fires a desktop notify-send on
# workstation hosts), then bumps any flake-pinned upstream skills
# (currently just `humanizer-skill` -> blader/humanizer). Skills authored
# in this repo under config/skills/ are managed by claude-capture and need
# no separate update step.
update-skills:
    #!/usr/bin/env bash
    set -euo pipefail
    if command -v claude-skill-updates >/dev/null 2>&1; then
        claude-skill-updates || echo "skillfish update failed (non-fatal)"
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
#
# When run off qbert this is a DRY-RUN by default: capture-sync still
# computes the three-way diff and prints what would change, but does not
# write to the repo or to the snapshot. Set JUST_CAPTURE_FORCE=1 to
# actually apply on a non-canonical host (uncommon, and the right thing
# to do if you've just installed something new on that host and want
# to commit it from there).
capture:
    #!/usr/bin/env bash
    set -uo pipefail
    if [[ "$(hostname)" != "qbert" && "${JUST_CAPTURE_FORCE:-0}" != "1" ]]; then
        echo "just capture: running on non-canonical host $(hostname) in DRY-RUN mode."
        echo "  To actually apply, re-run with JUST_CAPTURE_FORCE=1 just capture."
        echo "  Without the override only the dry-run summary is printed; the"
        echo "  repo and .capture-state.json are not modified."
        echo ""
        # capture-sync respects --dry-run. Anchor paths on
        # justfile_directory() rather than $(pwd) so the recipe is safe
        # to invoke from any working directory.
        config_dir="{{justfile_directory()}}/modules/apps/cli/claude-code/config"
        sync_output=$(python3 "{{justfile_directory()}}/modules/apps/cli/claude-code/cfg/scripts/capture-sync.py" \
            --state-file "$config_dir/.capture-state.json" \
            --home-root "$HOME/.claude" \
            --repo-root "$config_dir" \
            --section all \
            --dry-run)
        echo "$sync_output" | jq -r '.actions[].action' | sort | uniq -c | awk '{printf "  %-12s: %s\n", $2, $1}'
        conflicts=$(echo "$sync_output" | jq -r '.conflicts | length')
        if [[ "$conflicts" -gt 0 ]]; then
            echo "  conflicts   : $conflicts"
        fi
        exit 0
    fi
    echo "Capturing Claude Code config..."
    fish -c 'claude-capture' || echo "Claude capture failed (non-fatal)"
    echo "Capturing Agent OS config..."
    fish -c 'agentos-capture' || echo "Agent OS capture failed (non-fatal)"
    echo ""
    echo "Review with: git status && git diff modules/apps/cli/claude-code modules/apps/cli/agentos"

# Resolve a capture-sync conflict by picking which side wins.
# Usage: just capture-resolve skills/gsuite-edit/SKILL.md --home
#        just capture-resolve agents/foo.md --repo
# Updates the snapshot in .capture-state.json so the next `just qr` is a
# no-op for this file. Stage the resulting change in git as usual.
#
# Both args are passed through fish as separate $argv elements (not
# concatenated into a fish -c command string) so attacker-controlled
# characters in a filename can't inject shell syntax even if the
# resulting conflict line ever surfaces such a name to the user.
capture-resolve relpath side:
    #!/usr/bin/env bash
    set -euo pipefail
    fish -c 'capture-resolve "$argv[1]" "$argv[2]"' -- {{quote(relpath)}} {{quote(side)}}

# === Shared Helpers ===
rebuild_log := "/tmp/nixerator-rebuild.log"
upgrade_log := "/tmp/nixerator-upgrade.log"

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

# Post-rebuild: sync plugins, restart DMS, capture config, check for changes
# mode: "interactive" (gum spin) or "quiet" (plain echo)
#
# DankMaterialShell loads ~/.config/DankMaterialShell/settings.json once at
# startup and does not live-watch it, so a rebuild that rewrites that file
# (e.g. a hyprflake dank settings change) has no visible effect until the
# running shell is restarted. We bounce dms.service here, guarded on is-active
# so headless hosts without the desktop shell skip it.
#
# The bounce is ALSO skipped when the screen is locked. DMS owns the
# ext-session-lock surface while locked; restarting it kills that client
# without unlocking, so Hyprland keeps the session locked (its emergency
# fallback) and the freshly started DMS crash-loops on the orphaned lock
# (wl_display "invalid object") until the lock clears. If the screen idle-locks
# during a long rebuild, an unguarded restart here is exactly that collision.
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
    # Detect an active screen lock so the DMS bounce below can skip it (see the
    # recipe header). Any of the user's sessions reporting LockedHint=yes counts.
    screen_locked=false
    if loginctl --no-legend list-sessions 2>/dev/null | awk -v u="$USER" '$3==u{print $1}' \
         | xargs -r -I{} loginctl show-session {} -p LockedHint --value 2>/dev/null \
         | grep -q '^yes$'; then
        screen_locked=true
    fi
    if [[ "{{mode}}" == "interactive" ]]; then
        gum spin --spinner dot --title "Syncing plugins..." \
            -- bash -c 'claude-sync-plugins &>/dev/null' || gum style --foreground 220 "Plugin sync failed (non-fatal)"
        # Run visibly (not inside a gum spin) so claude-skill-updates'
        # "updated N skill(s)" report reaches the terminal; the spinner's
        # &>/dev/null would otherwise swallow it. The desktop notify-send
        # still fires regardless.
        echo "Updating skills..."
        just update-skills || gum style --foreground 220 "Skill update failed (non-fatal)"
        if systemctl --user is-active --quiet dms.service; then
            if $screen_locked; then
                gum style --foreground 220 "Screen locked; skipping DMS restart (would orphan the session lock). Run 'systemctl --user restart dms.service' after unlocking."
            else
                gum spin --spinner dot --title "Restarting DankMaterialShell..." \
                    -- bash -c 'systemctl --user restart dms.service' || gum style --foreground 220 "DMS restart failed (non-fatal)"
            fi
        fi
        if command -v hyprflake-updates >/dev/null 2>&1; then
            hyprflake-updates || true
        fi
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
        if systemctl --user is-active --quiet dms.service; then
            if $screen_locked; then
                echo "Screen locked; skipping DMS restart (would orphan the session lock). Run 'systemctl --user restart dms.service' after unlocking."
            else
                echo "Restarting DankMaterialShell..."
                systemctl --user restart dms.service || echo "DMS restart failed (non-fatal)"
            fi
        fi
        if command -v hyprflake-updates >/dev/null 2>&1; then
            echo "Checking for DankMaterialShell / Hyprland updates..."
            hyprflake-updates || true
        fi
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

    just pre-rebuild quiet

    echo "Rebuilding (quiet mode)..."
    git add -A
    trap 'git restore --staged .' EXIT
    rc=0
    sudo nixos-rebuild switch --impure --flake {{host_flake}} &> {{rebuild_log}} || rc=$?
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
    just pre-rebuild quiet
    echo "Upgrading (quiet mode)..."
    cp flake.lock flake.lock-backup-{{timestamp}}
    rc=0
    {
        nix flake update
        sudo nixos-rebuild switch --impure --upgrade --flake {{host_flake}}
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
#
# Secrets: rebuilds read ~/.config/nixos-secrets/secrets.json on the target
# host. They are NOT re-rendered here — that's `just render-secrets` (local) or
# `just push-secrets <host>` (render + scp to a peer), run manually when 1Password
# values change. See extras/docs/secrets.md.
remote-rebuild host repo_path="~/git/nixerator":
    #!/usr/bin/env bash
    set -uo pipefail
    case "{{host}}" in
        qbert|donkeykong|srv) ;;
        *)
            echo "Refusing to ssh to unrecognized host: {{host}}"
            echo "Allowed: qbert, donkeykong, srv"
            exit 1
            ;;
    esac
    echo "Rebuilding {{host}} via SSH..."
    rc=0
    ssh -A -o BatchMode=yes -o ConnectTimeout=5 "{{host}}" \
        "cd {{repo_path}} && git pull --ff-only && just qr" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Remote rebuild on {{host}} succeeded."
    else
        echo "Remote rebuild on {{host}} FAILED (exit $rc)."
        exit "$rc"
    fi

# Remote upgrade — pull and full upgrade (flake update + rebuild) on another
# nixerator host over SSH. Same prereqs as `remote-rebuild`. Heavier than
# `rr` because the remote runs `nix flake update` before rebuilding.
remote-upgrade host repo_path="~/git/nixerator":
    #!/usr/bin/env bash
    set -uo pipefail
    case "{{host}}" in
        qbert|donkeykong|srv) ;;
        *)
            echo "Refusing to ssh to unrecognized host: {{host}}"
            echo "Allowed: qbert, donkeykong, srv"
            exit 1
            ;;
    esac
    echo "Upgrading {{host}} via SSH..."
    rc=0
    ssh -A -o BatchMode=yes -o ConnectTimeout=5 "{{host}}" \
        "cd {{repo_path}} && git pull --ff-only && just qu" || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Remote upgrade on {{host}} succeeded."
    else
        echo "Remote upgrade on {{host}} FAILED (exit $rc)."
        exit "$rc"
    fi

# Render Nix-eval secrets locally from 1Password into
# ~/.config/nixos-secrets/secrets.json. Triggers one biometric prompt per
# rotation; rebuilds in between read the cached file.
render-secrets:
    @render-secrets

# Render locally AND scp the rendered file to one or more peer hosts. Use
# after rotating a 1Password value, before running `just remote-rebuild <host>`
# against any peer that should see the new value.
#
#   just push-secrets srv
#   just push-secrets srv qbert
#
# Hostnames are validated against an allow-list; render-secrets itself also
# enforces the same allow-list. The recipe quotes each host individually so a
# host string containing shell metacharacters cannot inject commands.
push-secrets +hosts:
    #!/usr/bin/env bash
    set -euo pipefail
    for host in {{hosts}}; do
        case "$host" in
            qbert|donkeykong|srv) ;;
            *)
                echo "Refusing to push to unrecognized host: $host"
                echo "Allowed: qbert, donkeykong, srv"
                exit 1
                ;;
        esac
    done
    render-secrets --push {{hosts}}

# Render to a tempfile and diff against the live ~/.config/nixos-secrets/secrets.json.
# Exits non-zero if 1Password values differ from the cached file. Read-only.
check-secrets:
    @render-secrets --check

# Install the 1Password service-account token at ~/.config/op/service-account-token
# (0600), so render-secrets / push-secrets / check-secrets run with zero
# biometric prompts thereafter. One-time per host.
#
# Default behaviour: `op read` fetches the token from your Personal vault
# (one biometric on the desktop). Pass-through args support the helper's
# alternate inputs:
#
#   just setup-op-token                            # op read (default, preferred)
#   just setup-op-token --manual                   # interactive paste
#   just setup-op-token --force                    # overwrite an existing different token
#   OP_TOKEN=ops_... just setup-op-token           # from env var (no prompts)
#
# See extras/docs/helpers.md for the full helper docs.
setup-op-token *args:
    @./extras/helpers/setup-op-service-account.sh {{args}}

# Pre-rebuild bootstrap render: writes ~/.config/nixos-secrets/secrets.json
# WITHOUT needing render-secrets on PATH yet. Use ONLY on a fresh machine
# before the first rebuild lands the Nix-packaged render-secrets. After that
# first rebuild, prefer `just render-secrets`.
#
# Auth is the same as render-secrets -- if you ran `just setup-op-token`
# first, this runs with no prompts.
bootstrap-secrets:
    @./extras/helpers/render-secrets-bootstrap.sh

# Fetch the Okular signature + initials PNGs from the nixerator 1Password
# vault (Document items okular-signature + okular-initials) to
# ~/.kde/share/icons/{signature,initials}.png. One-time per host after
# `just setup-op-token`; re-run only if you rotate the documents in 1P.
fetch-signatures:
    @./extras/helpers/fetch-okular-signatures.sh

# === Aliases ===
alias r := rebuild
alias up := upgrade
alias gc := clean
alias qr := quiet-rebuild
alias qu := quiet-upgrade
alias rr := remote-rebuild
alias ru := remote-upgrade
alias rs := render-secrets
alias ps := push-secrets
alias cs := check-secrets
alias fs := fetch-signatures
alias gen := generations
alias rb := rollback
