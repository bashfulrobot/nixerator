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

# Open the visual repo tour (extras/docs/index.html) in a browser
docs:
    #!/usr/bin/env bash
    if command -v xdg-open >/dev/null 2>&1; then xdg-open extras/docs/index.html
    else open extras/docs/index.html; fi

# === Core Recipes ===
# Production rebuild of the current host
rebuild:
    #!/usr/bin/env bash
    set -uo pipefail
    just secrets-nudge
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

# Build (not switch) an arbitrary host's system closure to verify it evaluates
# and compiles. Works from any host and never activates. Use to validate a new
# host config before installing it on the target machine.
#
#   just build-host srv
build-host host:
    nixos-rebuild build --impure --flake ".#{{host}}"

# Stage all, rebuild, unstage on exit
dev-rebuild:
    #!/usr/bin/env bash
    set -uo pipefail
    gum style --foreground 245 "Staging all changes..."
    git add -A
    trap 'git restore --staged .' EXIT
    just rebuild

# Test a local hyprflake checkout against the current host.
#
# Rebuilds the current host but overrides the `hyprflake` flake input to point
# at a local working tree (default: ~/git/hyprflake) so changes can be tried
# without committing/pushing hyprflake or bumping flake.lock. Pass an alternate
# path to test a different checkout/worktree:
#
#   just hyprflake-test
#   just hyprflake-test /home/dustin/git/.worktrees/hyprflake-feature
#
# Uses {{host_flake}} so it targets whichever host it runs on, like `rebuild`.
hyprflake-test path="/home/dustin/git/hyprflake":
    #!/usr/bin/env bash
    set -uo pipefail
    if [[ ! -d "{{path}}" ]]; then
        gum style --foreground 196 "hyprflake path not found: {{path}}"
        exit 1
    fi
    just secrets-nudge
    log="{{rebuild_log}}"
    rc=0
    gum spin --spinner dot --title "Rebuilding with local hyprflake ({{path}})..." \
        -- bash -c 'sudo nixos-rebuild switch --impure --flake {{host_flake}} --override-input hyprflake path:{{path}} &> "'"$log"'"' || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        warnings=$(grep -c -E -i 'warning:' "$log" 2>/dev/null || true)
        if [[ "$warnings" -gt 0 ]]; then
            gum style --foreground 220 "Rebuild succeeded with $warnings warning(s)"
            if gum confirm "View warnings in log?"; then
                bat --paging=always "$log"
            fi
        else
            gum style --foreground 82 "Rebuild succeeded (local hyprflake override active)"
        fi
    else
        gum style --foreground 196 "Rebuild FAILED (exit $rc)"
        bat --paging=always "$log"
        exit "$rc"
    fi

# Full system upgrade
upgrade:
    #!/usr/bin/env bash
    set -uo pipefail
    just secrets-nudge
    just pre-rebuild interactive
    log="{{upgrade_log}}"
    cp flake.lock flake.lock-backup-{{timestamp}}
    # Keep only the 5 newest lock backups.
    ls -1t flake.lock-backup-* 2>/dev/null | tail -n +6 | xargs -r rm -f
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
    # Auto-commit + push the refreshed lock so it never lingers uncommitted or
    # unpushed. Push is gated to main (post-rebuild only pushes main too) and
    # non-fatal: a failed push keeps the local commit and warns.
    if ! git diff --quiet flake.lock; then
        if git add flake.lock && git commit -q -m "chore(flake): update flake lock"; then
            gum style --foreground 82 "Committed flake.lock"
            if [[ "$(git branch --show-current 2>/dev/null)" == "main" ]]; then
                if git push -q origin main 2>/dev/null; then
                    gum style --foreground 82 "Pushed flake.lock to origin/main"
                else
                    gum style --foreground 220 "flake.lock committed but push failed — push manually"
                fi
            fi
        else
            gum style --foreground 220 "flake.lock updated but commit failed — commit it manually"
        fi
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

# Run render-secrets unit tests (Forgejo tea-config generation)
test-render-secrets:
    nix shell nixpkgs#bats nixpkgs#jq --command bats modules/apps/cli/render-secrets/tests/

# Run the claude-code PreToolUse guard-hook regression tests (secret-leak +
# primary-tree-write) plus the capture-sync settings suite in the same dir. git
# drives the primary-vs-worktree detection, coreutils provides sort/cut for the
# cwd-replay resolver, and python3 runs the capture-sync reconcile tests.
test-secret-guard:
    nix shell nixpkgs#bats nixpkgs#jq nixpkgs#gnugrep nixpkgs#git nixpkgs#coreutils nixpkgs#python3 --command bats modules/apps/cli/claude-code/cfg/scripts/tests/

# Run the capture-sync settings.json 3-way reconcile regression tests
test-capture-sync:
    nix shell nixpkgs#bats nixpkgs#jq nixpkgs#python3 --command bats modules/apps/cli/claude-code/cfg/scripts/tests/capture-sync-settings.bats

# Run worktree-flow unit tests (github-issue setup branch preflight)
test-worktree-flow:
    nix shell nixpkgs#bats nixpkgs#jq nixpkgs#git --command bats modules/apps/cli/worktree-flow/tests/

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

# Ad-hoc capture of live ~/.claude, ~/agent-os, and DMS (dank) state into the repo.
#
# Auto-capture during rebuild is gated to qbert (the designated source of
# truth) so non-canonical hosts don't regress the repo. Use this recipe to
# manually surface a new skill/agent/setting or DMS GUI change installed on any
# other host (donkeykong, etc.) -- review the resulting diff and commit only the
# bits that should propagate. DMS settings land in dank-profiles/<group>.json.
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
    # DMS (dank) is host-agnostic: any workstation may capture its DMS settings
    # into the shared dank-profiles/<group>.json, so it ALWAYS applies here --
    # it is not gated to qbert like the claude/agentos capture below. Review the
    # resulting dank-profiles/ diff and commit only deliberate changes (a shared
    # full-file profile means any per-host DMS divergence shows up as a diff).
    if command -v dank-capture >/dev/null 2>&1 && [[ -e "$HOME/.config/DankMaterialShell/settings.json" ]]; then
        echo "Capturing DMS (dank) settings..."
        dank-capture || echo "DMS capture failed (non-fatal)"
        echo ""
    fi
    if [[ "$(hostname)" != "qbert" && "${JUST_CAPTURE_FORCE:-0}" != "1" ]]; then
        echo "just capture: claude/agentos capture is gated to qbert; on $(hostname) those run in DRY-RUN mode (DMS was captured above)."
        echo "  To also apply claude/agentos here, re-run with JUST_CAPTURE_FORCE=1 just capture."
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
        echo ""
        echo "Review DMS capture with: git diff dank-profiles"
        exit 0
    fi
    echo "Capturing Claude Code config..."
    fish -c 'claude-capture' || echo "Claude capture failed (non-fatal)"
    echo "Capturing Agent OS config..."
    fish -c 'agentos-capture' || echo "Agent OS capture failed (non-fatal)"
    echo ""
    echo "Review with: git status && git diff modules/apps/cli/claude-code modules/apps/cli/agentos dank-profiles"

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

# Secrets freshness nudge, run at the top of every switch recipe. A rebuild
# reads ~/.config/nixos-secrets/secrets.json at eval time, so a stale render can
# bake outdated values into the system. This is a pure local mtime check -- no
# 1Password, no network -- so it never slows or blocks a rebuild. It stays quiet
# unless secrets.json.tpl has moved ahead of the last render (a secret was added
# or rotated but not yet rendered on this host) or the host has never rendered at
# all. In that case a human or agent gets a 1s window to abort and run
# `just render-secrets`; otherwise the rebuild continues.
[private]
secrets-nudge:
    #!/usr/bin/env bash
    set -uo pipefail
    tpl="secrets.json.tpl"
    cache="$HOME/.config/nixos-secrets/secrets.json"
    if [[ -f "$tpl" ]] && { [[ ! -f "$cache" ]] || [[ "$tpl" -nt "$cache" ]]; }; then
        echo "⚠ secrets.json.tpl has changed since the last render (or was never rendered on this host)."
        echo "  If a secret was added or rotated, run: just render-secrets"
        echo "  Continuing rebuild in 1s -- Ctrl-C to abort."
        sleep 1
    fi

# Pre-rebuild: capture runtime ~/.claude/* edits back into the source tree
# before activation overwrites them with the previously-captured version.
# Without this, any change made directly to a managed file (CLAUDE.md,
# settings.json, agents, skills, output-styles, plugin metadata) between
# rebuilds is silently lost when the activation script runs.
#
# DMS (dank) is captured here too, and the ordering is deliberate: dank-capture
# harvests the live ~/.config/DankMaterialShell/settings.json into
# dank-profiles/<group>.json BEFORE the rebuild evaluates the flake, so the same
# rebuild's dank seed re-derives exactly what was captured (live == seed marker)
# instead of tripping the seed clobber-guard's "un-captured GUI edits" warning.
# Capturing after activation would lag a rebuild and warn. The dank module
# preserves un-captured edits rather than wiping them, so there is no data-loss
# risk. Unlike claude/agentos (qbert-only), DMS capture runs on EVERY host: any
# workstation may contribute DMS settings to the shared profile. The captures are
# never auto-committed -- post-rebuild surfaces the diff for you to review, so a
# host with divergent DMS state can't silently clobber the shared profile.
# mode: "interactive" (gum spin) or "quiet" (plain echo)
[private]
pre-rebuild mode="quiet":
    #!/usr/bin/env bash
    set -uo pipefail
    # DMS (dank): host-agnostic, so capture BEFORE the qbert gate below. Writes
    # the live settings into dank-profiles/ so this same rebuild seeds them.
    if command -v dank-capture >/dev/null 2>&1 && [[ -e "$HOME/.config/DankMaterialShell/settings.json" ]]; then
        if [[ "{{mode}}" == "interactive" ]]; then
            gum spin --spinner dot --title "Capturing live DMS settings (pre-rebuild)..." \
                -- bash -c 'dank-capture &>/dev/null' || gum style --foreground 220 "DMS pre-capture failed (non-fatal)"
        else
            echo "Capturing live DMS settings (pre-rebuild)..."
            dank-capture &>/dev/null || echo "DMS pre-capture failed (non-fatal)"
        fi
    fi
    # claude/agentos capture flows live ~/.claude state into the repo. Only qbert
    # is the designated source -- other hosts (donkeykong, srv, ...) carry
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
        # Plugins are synced declaratively at activation (settings.json
        # overlay from cfg/plugin-config.nix); no runtime sync step needed.
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
        # Plugins synced declaratively at activation; no runtime sync step.
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

    # Auto-commit + push captured state so a rebuild leaves nothing uncommitted.
    #
    # Branch gate: we only auto-commit + push when HEAD is `main`. On any other
    # branch we fall back to surfacing the diff for manual review, so capture
    # commits never land on an unrelated feature branch.
    #
    # Scope: commits use the pathspec form `git commit -- <paths>`, which records
    # ONLY the named capture paths. This is load-bearing — `quiet-rebuild` runs
    # `git add -A` (so the flake sees untracked files) before calling this
    # recipe, so a bare `git commit` would sweep the entire index into the
    # capture commit. The pathspec form ignores everything staged for other
    # paths; the preceding `git add -- <paths>` only ensures new/modified capture
    # files are staged. Net effect: scoped commit regardless of what else is
    # staged, and never a `git add -A` commit.
    #
    # Host gate: claude/agentos capture stays gated to the capture source
    # (qbert) via is_capture_source; DMS (dank) settings commit on every host.
    branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo unknown)
    on_main=false
    [[ "$branch" == "main" ]] && on_main=true
    did_commit=false

    notice() { if [[ "{{mode}}" == "interactive" ]]; then gum style --foreground 82 "$1"; else echo "$1"; fi; }
    warn()   { if [[ "{{mode}}" == "interactive" ]]; then gum style --foreground 220 "$1"; else echo "$1"; fi; }

    # commit_captures <label> <commit-msg> <path>...
    # On main: stage + pathspec-commit exactly the given paths, set did_commit.
    # Off main: surface the diff for manual review (the pre-auto-commit behaviour).
    commit_captures() {
        local label="$1" msg="$2"; shift 2
        local paths=("$@")
        [[ -z "$(git status --porcelain -- "${paths[@]}" 2>/dev/null)" ]] && return 0
        echo ""
        if $on_main; then
            git add -- "${paths[@]}" 2>/dev/null || true
            # `git commit -- <pathspec>` aborts the WHOLE commit if any pathspec
            # matches no tracked files (e.g. agentos/config when the capture
            # produced no diffs and the dir holds nothing git-known). Commit only
            # the paths that actually have staged changes so one empty capture
            # path can't sink a sibling path's real changes.
            local committable=()
            for p in "${paths[@]}"; do
                git diff --cached --quiet -- "$p" 2>/dev/null || committable+=("$p")
            done
            [[ ${#committable[@]} -eq 0 ]] && return 0
            if git commit -q -m "$msg" -- "${committable[@]}"; then
                did_commit=true
                notice "$label captured and committed: $msg"
                notify-send "Nixerator" "$label captured and committed" 2>/dev/null || true
            else
                warn "$label captured but commit failed — commit manually:"
                warn "  git add ${committable[*]} && git commit -m \"$msg\" -- ${committable[*]}"
                notify-send "Nixerator" "$label capture commit failed" 2>/dev/null || true
            fi
        else
            warn "$label captured (on branch '$branch', not main) — review and commit manually:"
            warn "  git add ${paths[*]} && git commit -m \"$msg\" -- ${paths[*]}"
            notify-send "Nixerator" "$label captured — review and commit" 2>/dev/null || true
        fi
    }

    if $is_capture_source; then
        commit_captures "Claude/Agent OS config" \
            'chore(claude-code): update captured config state' \
            modules/apps/cli/claude-code/config modules/apps/cli/agentos/config
    fi
    # DMS (dank) settings are captured in pre-rebuild (before the seed) on EVERY
    # host -- not gated to qbert -- so commit any change on its own scope here.
    commit_captures "DMS settings" \
        'chore(dank): update captured DMS settings' \
        dank-profiles

    # Push once if anything was committed. did_commit is only ever set on main,
    # so this only pushes main. A failed push (diverged remote, no upstream) is
    # non-fatal: keep the local commit(s), warn, and let the rebuild finish.
    if $did_commit; then
        if git push -q origin main 2>/dev/null; then
            notice "Pushed captured config to origin/main"
            notify-send "Nixerator" "Captured config pushed to origin/main" 2>/dev/null || true
        else
            warn "Capture commit(s) made but push failed — resolve manually: git pull --rebase origin main && git push origin main"
            notify-send "Nixerator" "Capture push failed — resolve manually" 2>/dev/null || true
        fi
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

    just secrets-nudge
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
    just secrets-nudge
    just pre-rebuild quiet
    echo "Upgrading (quiet mode)..."
    cp flake.lock flake.lock-backup-{{timestamp}}
    # Keep only the 5 newest lock backups.
    ls -1t flake.lock-backup-* 2>/dev/null | tail -n +6 | xargs -r rm -f
    rc=0
    # &&-chain so a failed `nix flake update` aborts instead of rebuilding on
    # the old lock (a bare `;` group would mask its exit status).
    {
        nix flake update \
            && sudo nixos-rebuild switch --impure --upgrade --flake {{host_flake}} \
            && just ref::voxtype-setup
    } &> {{upgrade_log}} || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Upgrade succeeded. Full log: {{upgrade_log}}"
        # Auto-commit + push the refreshed lock so it never lingers uncommitted
        # or unpushed. Push is gated to main (post-rebuild only pushes main too)
        # and non-fatal: a failed push keeps the local commit and warns.
        if ! git diff --quiet flake.lock; then
            if git add flake.lock && git commit -q -m "chore(flake): update flake lock"; then
                echo "Committed flake.lock."
                if [[ "$(git branch --show-current 2>/dev/null)" == "main" ]]; then
                    if git push -q origin main 2>/dev/null; then
                        echo "Pushed flake.lock to origin/main."
                    else
                        echo "⚠ flake.lock committed but push failed — push manually."
                    fi
                fi
            else
                echo "⚠ flake.lock updated but commit failed — commit it manually."
            fi
        fi

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

# Bump the `upsight` input (github:bashfulrobot/upsight) to latest + rebuild current host; commits + pushes flake.lock to main. For iterating on the app.
bump-upsight:
    #!/usr/bin/env bash
    set -uo pipefail
    just pre-rebuild quiet
    echo "Bumping upsight input + rebuilding (quiet mode)..."
    # Back up the lock so a failed bump reverts cleanly and never leaves the tree
    # pinned to a broken upsight commit (an un-buildable next rebuild).
    cp flake.lock flake.lock-backup-bump
    rc=0
    # &&-chain so a failed input update aborts instead of rebuilding on the old
    # lock (a bare `;` group would mask its exit status).
    {
        # --refresh bypasses Nix's tarball-ttl (default 1h) so back-to-back
        # iterations always re-query GitHub HEAD instead of re-locking to a
        # cached commit (which silently no-ops the rebuild).
        nix flake update upsight --refresh \
            && sudo nixos-rebuild switch --impure --flake {{host_flake}}
    } &> {{rebuild_log}} || rc=$?
    # `nixos-rebuild switch` exits non-zero when a unit fails to (re)start during
    # activation (e.g. systemd-bless-boot on a boot entry without a counter) even
    # though the new system built and activated fine. Only revert when the build
    # never reached activation (a genuinely un-buildable pin). A non-zero exit that
    # still printed "activating the configuration" is unit-restart noise — an
    # idempotent re-run advances no profile either, so gate on activation, not on
    # the exit code or a profile diff.
    if [[ "$rc" -eq 0 ]] || grep -qF 'activating the configuration' {{rebuild_log}}; then
        if [[ "$rc" -ne 0 ]]; then
            echo "⚠ New config activated but a unit failed to (re)start (exit $rc). Review {{rebuild_log}}."
        fi
        rm -f flake.lock-backup-bump
        echo "upsight bumped + rebuilt. Full log: {{rebuild_log}}"
        # Auto-commit + push the refreshed lock so it never lingers uncommitted
        # or unpushed. Push is gated to main and non-fatal: a failed push keeps
        # the local commit and warns.
        if ! git diff --quiet flake.lock; then
            if git add flake.lock && git commit -q -m "chore(flake): bump upsight input"; then
                echo "Committed flake.lock."
                if [[ "$(git branch --show-current 2>/dev/null)" == "main" ]]; then
                    if git push -q origin main 2>/dev/null; then
                        echo "Pushed flake.lock to origin/main."
                    else
                        echo "⚠ flake.lock committed but push failed — push manually."
                    fi
                fi
            else
                echo "⚠ flake.lock updated but commit failed — commit it manually."
            fi
        fi

        just post-rebuild quiet
    else
        # Revert the failed bump so flake.lock isn't left pointing at a broken
        # upsight commit; the system stays buildable on the prior good pin.
        mv -f flake.lock-backup-bump flake.lock
        echo "Reverted flake.lock (bump failed) — tree left on the prior good pin."
        filtered=$(grep -E -i '(^error|error:|warning:|trace:|fatal|failed to)' {{rebuild_log}} | head -80)
        {
            echo "=== FILTERED ERRORS/WARNINGS ==="
            echo "$filtered"
            echo ""
            echo "=== FULL BUILD LOG ==="
            cat {{rebuild_log}}
        } > {{rebuild_log}}.tmp
        mv {{rebuild_log}}.tmp {{rebuild_log}}
        echo "upsight bump FAILED (exit $rc). Use a Nix subagent to diagnose {{rebuild_log}} and fix the issue."
        exit "$rc"
    fi

# One command: bump + push hyprflake's inputs in its repo, then pull + rebuild here. Reverts the lock if the rebuild fails.
bump-hyprflake hyprflake_path="/home/dustin/git/hyprflake":
    #!/usr/bin/env bash
    set -uo pipefail
    echo "==> hyprflake repo: bump + push its inputs ({{hyprflake_path}})"
    if ! ( cd "{{hyprflake_path}}" && just bump-hyprflake ); then
        echo "hyprflake bump failed — aborting before touching nixerator."
        exit 1
    fi
    just pre-rebuild quiet
    echo "Bumping hyprflake input + rebuilding (quiet mode)..."
    # Back up the lock so a failed bump reverts cleanly and never leaves the tree
    # pinned to an un-buildable hyprflake commit.
    cp flake.lock flake.lock-backup-bump
    rc=0
    {
        # --refresh bypasses Nix's tarball-ttl so the just-pushed hyprflake HEAD
        # is re-queried instead of a cached commit (which would no-op the bump).
        nix flake update hyprflake --refresh \
            && sudo nixos-rebuild switch --impure --flake {{host_flake}}
    } &> {{rebuild_log}} || rc=$?
    # `nixos-rebuild switch` exits non-zero when a unit fails to (re)start during
    # activation (e.g. systemd-bless-boot on a boot entry without a counter) even
    # though the new system built and activated fine. Only revert when the build
    # never reached activation (a genuinely un-buildable pin). A non-zero exit that
    # still printed "activating the configuration" is unit-restart noise — an
    # idempotent re-run advances no profile either, so gate on activation, not on
    # the exit code or a profile diff.
    if [[ "$rc" -eq 0 ]] || grep -qF 'activating the configuration' {{rebuild_log}}; then
        if [[ "$rc" -ne 0 ]]; then
            echo "⚠ New config activated but a unit failed to (re)start (exit $rc). Review {{rebuild_log}}."
        fi
        rm -f flake.lock-backup-bump
        echo "hyprflake bumped + rebuilt. Full log: {{rebuild_log}}"
        # Auto-commit + push the refreshed lock, gated to main; push is non-fatal.
        if ! git diff --quiet flake.lock; then
            if git add flake.lock && git commit -qS -m "chore(flake): bump hyprflake input"; then
                echo "Committed flake.lock."
                if [[ "$(git branch --show-current 2>/dev/null)" == "main" ]]; then
                    if git push -q origin main 2>/dev/null; then
                        echo "Pushed flake.lock to origin/main."
                    else
                        echo "⚠ flake.lock committed but push failed — push manually."
                    fi
                fi
            else
                echo "⚠ flake.lock updated but commit failed — commit it manually."
            fi
        fi
        just post-rebuild quiet
    else
        # Revert so flake.lock isn't left on a broken hyprflake pin.
        mv -f flake.lock-backup-bump flake.lock
        echo "hyprflake bump/rebuild FAILED (exit $rc), reverted flake.lock. Log: {{rebuild_log}}"
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
# Default behaviour: `op read` fetches the token from the same 1Password item
# secrets.json.tpl's onepassword.serviceAccountToken points at (one biometric
# on the desktop). Pass-through args support the helper's alternate inputs:
#
#   just setup-op-token                            # op read (default, preferred)
#   just setup-op-token --manual                   # interactive paste
#   just setup-op-token --force                    # overwrite an existing different token
#   OP_TOKEN=ops_... just setup-op-token           # from env var (no prompts)
#
# Rotating the token, not just re-installing it on a new host? Use
# `just rotate-op-token` instead -- see below.
#
# See extras/docs/helpers.md for the full helper docs.
setup-op-token *args:
    @./extras/helpers/setup-op-service-account.sh {{args}}

# Walks through rotating the nixerator 1Password service-account token,
# end to end, on this host: prints the manual 1Password steps and waits,
# installs the new token locally, renders secrets.json with an EXPLICIT
# token override (bypassing op-toggle's chicken-and-egg fallback to a
# stale render), then verifies auth and reports which vaults are visible.
# Does NOT push to the fleet automatically -- it prints that command for
# you to run once you're happy with the verification output.
#
#   just rotate-op-token             # op read (default, preferred)
#   just rotate-op-token --manual    # interactive paste
#
# See extras/docs/helpers.md for the full helper docs.
rotate-op-token *args:
    @./extras/helpers/rotate-op-service-account.sh {{args}}

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

# Fetch the gmailctl OAuth client credentials from the nixerator 1Password
# vault (Login item `gmailctl`, Client ID + Client Secret fields) and render
# them into ~/.gmailctl/credentials.json (0600). One-time per host after
# `just setup-op-token`; re-run only if you rotate the OAuth client.
# Afterwards run `gmailctl init` to create token.json.
fetch-gmailctl-creds:
    @./extras/helpers/fetch-gmailctl-credentials.sh

# Generic form: fetch the OAuth client into an arbitrary config dir / item.
# gmailctl picks its dir via --config (NOT cwd), so each account = its own dir.
#   just fetch-gmailctl-creds-for ~/.gmailctl-kong gmailctl dustin@konghq.com
fetch-gmailctl-creds-for dir item="gmailctl" account="":
    @./extras/helpers/fetch-gmailctl-credentials.sh "{{dir}}" "{{item}}" "{{account}}"

# Kong work account, reusing the SAME OAuth client item (`gmailctl`). Writes
# ~/.gmailctl-kong/credentials.json; then run `gmailctl --config ~/.gmailctl-kong init`.
fetch-gmailctl-creds-kong:
    @./extras/helpers/fetch-gmailctl-credentials.sh "${HOME}/.gmailctl-kong" gmailctl dustin@konghq.com

# === Aliases ===
alias r := rebuild
alias hft := hyprflake-test
alias up := upgrade
alias gc := clean
alias qr := quiet-rebuild
alias qu := quiet-upgrade
alias ub := bump-upsight
alias rr := remote-rebuild
alias ru := remote-upgrade
alias rs := render-secrets
alias ps := push-secrets
alias cs := check-secrets
alias fs := fetch-signatures
alias rot := rotate-op-token
alias fgc := fetch-gmailctl-creds
alias fgck := fetch-gmailctl-creds-kong
alias gen := generations
alias rb := rollback
