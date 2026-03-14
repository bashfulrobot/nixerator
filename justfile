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
        # Post-rebuild: sync plugins, capture state, check for changes
        gum spin --spinner dot --title "Syncing plugins..." \
            -- bash -c 'claude-sync-plugins &>/dev/null' || gum style --foreground 220 "Plugin sync failed (non-fatal)"
        gum spin --spinner dot --title "Capturing Claude Code config..." \
            -- bash -c 'fish -c "claude-capture" &>/dev/null' || gum style --foreground 220 "Capture failed (non-fatal)"

        if ! git diff --quiet modules/apps/cli/claude-code/config/plugins/ 2>/dev/null; then
            commit_msg='fix(claude-code): update captured plugin state'
            echo ""
            gum style --foreground 220 --bold "Plugin config changed! Commit with:"
            echo "  git add modules/apps/cli/claude-code/config/plugins/ && git commit -m \"$commit_msg\""
            echo "$commit_msg" | wl-copy 2>/dev/null || true
            notify-send "Nixerator" "Plugin config changed — commit suggested" 2>/dev/null || true
        fi

        # Run package update check in background, show results when done
        echo ""
        bash extras/scripts/check-pkg-updates.bash 2>/dev/null || true
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
    # Post-rebuild: sync plugins, capture state, check for changes
    gum spin --spinner dot --title "Syncing plugins..." \
        -- bash -c 'claude-sync-plugins &>/dev/null' || gum style --foreground 220 "Plugin sync failed (non-fatal)"
    gum spin --spinner dot --title "Capturing Claude Code config..." \
        -- bash -c 'fish -c "claude-capture" &>/dev/null' || gum style --foreground 220 "Capture failed (non-fatal)"

    if ! git diff --quiet modules/apps/cli/claude-code/config/plugins/ 2>/dev/null; then
        commit_msg='fix(claude-code): update captured plugin state'
        echo ""
        gum style --foreground 220 --bold "Plugin config changed! Commit with:"
        echo "  git add modules/apps/cli/claude-code/config/plugins/ && git commit -m \"$commit_msg\""
        echo "$commit_msg" | wl-copy 2>/dev/null || true
        notify-send "Nixerator" "Plugin config changed — commit suggested" 2>/dev/null || true
    fi

    # Run package update check after successful upgrade
    echo ""
    bash extras/scripts/check-pkg-updates.bash 2>/dev/null || true

# Update a specific flake input
update input:
    @echo "Updating {{input}}..."
    @nix flake update {{input}}

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
        git reset "origin/$current_branch"
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

# === Quiet Recipes ===
rebuild_log := "/tmp/nixerator-rebuild.log"
upgrade_log := "/tmp/nixerator-upgrade.log"

# Quiet rebuild -- captures output, shows only errors on failure
quiet-rebuild:
    #!/usr/bin/env bash
    set -uo pipefail

    # Pre-rebuild guard: warn about uncommitted plugin changes
    if ! git diff --quiet modules/apps/cli/claude-code/config/plugins/ 2>/dev/null; then
        echo "⚠ Uncommitted plugin changes from a previous sync. Commit or discard before rebuilding."
    fi

    echo "Rebuilding (quiet mode)..."
    git add -A
    trap 'git restore --staged .' EXIT
    rc=0
    sudo nixos-rebuild switch --impure --flake {{host_flake}} &> {{rebuild_log}} || rc=$?
    if [[ "$rc" -eq 0 ]]; then
        echo "Rebuild succeeded. Full log: {{rebuild_log}}"

        # Post-rebuild: sync plugins, capture state, check for changes
        echo "Syncing plugins..."
        claude-sync-plugins || echo "Plugin sync failed (non-fatal)"

        echo "Capturing Claude Code config..."
        fish -c 'claude-capture' || echo "Capture failed (non-fatal)"

        if ! git diff --quiet modules/apps/cli/claude-code/config/plugins/ 2>/dev/null; then
            commit_msg='fix(claude-code): update captured plugin state'
            echo ""
            echo "════════════════════════════════════════════════════════════"
            echo "  Plugin config changed! Commit with:"
            echo "  git add modules/apps/cli/claude-code/config/plugins/ && git commit -m \"$commit_msg\""
            echo "════════════════════════════════════════════════════════════"
            echo "$commit_msg" | wl-copy 2>/dev/null || true
            notify-send "Nixerator" "Plugin config changed — commit suggested" 2>/dev/null || true
        fi
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

        # Post-rebuild: sync plugins, capture state, check for changes
        echo "Syncing plugins..."
        claude-sync-plugins || echo "Plugin sync failed (non-fatal)"

        echo "Capturing Claude Code config..."
        fish -c 'claude-capture' || echo "Capture failed (non-fatal)"

        if ! git diff --quiet modules/apps/cli/claude-code/config/plugins/ 2>/dev/null; then
            commit_msg='fix(claude-code): update captured plugin state'
            echo ""
            echo "════════════════════════════════════════════════════════════"
            echo "  Plugin config changed! Commit with:"
            echo "  git add modules/apps/cli/claude-code/config/plugins/ && git commit -m \"$commit_msg\""
            echo "════════════════════════════════════════════════════════════"
            echo "$commit_msg" | wl-copy 2>/dev/null || true
            notify-send "Nixerator" "Plugin config changed — commit suggested" 2>/dev/null || true
        fi
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

# === Aliases ===
alias r := rebuild
alias up := upgrade
alias gc := clean
alias qr := quiet-rebuild
alias qu := quiet-upgrade
