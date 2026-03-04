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
    @echo "Rebuilding..."
    @sudo nixos-rebuild switch --impure --flake {{host_flake}}

# Stage all, rebuild, unstage on exit
dev-rebuild:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Staging all changes for dev rebuild..."
    git add -A
    trap 'echo "Unstaging changes..."; git restore --staged .' EXIT
    just rebuild

# Full system upgrade
upgrade:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Upgrading system..."
    cp flake.lock flake.lock-backup-{{timestamp}}
    nix flake update
    sudo nixos-rebuild switch --impure --upgrade --flake {{host_flake}}
    just ref::voxtype-setup

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

# === Aliases ===
alias r := rebuild
alias up := upgrade
alias gc := clean
