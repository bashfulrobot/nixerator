# NixOS Configuration Management
# https://github.com/casey/just

# === Settings ===
set dotenv-load := true
set ignore-comments := true
set fallback := true
set shell := ["bash", "-euo", "pipefail", "-c"]

# === Variables ===
hostname := `hostname`
host_flake := ".#" + hostname
trace_log := justfile_directory() + "/rebuild-trace.log"
timestamp := `date +%Y-%m-%d_%H-%M-%S`
openspec_tools_default := "claude,codex,github-copilot,gemini"
openspec_workflows_all_json := "[\"propose\",\"explore\",\"new\",\"continue\",\"apply\",\"ff\",\"sync\",\"archive\",\"bulk-archive\",\"verify\",\"onboard\"]"

# === Help ===
# Show available recipes
default:
    @echo "📋 NixOS Configuration Management Commands"
    @echo "=========================================="
    @just --list --unsorted
    @echo ""
    @echo "🔧 Commands with Parameters:"
    @echo "  build [trace=true]         - Add trace=true for detailed debugging"
    @echo "  build-staged [trace=true]  - Stage all changes then run build"
    @echo "  dev-rebuild [trace=true]   - Stage all, run rebuild, then unstage"
    @echo "  rebuild [trace=true]       - Add trace=true for detailed debugging"
    @echo "  rebuild-staged [trace=true] - Stage all changes then run rebuild"
    @echo "  log [days=7]               - Show commits from last N days"
    @echo "  lint [target=.]            - Lint specific file/directory"
    @echo "  openspec-init-global [tools={{openspec_tools_default}}] - Initialize OpenSpec globally"
    @echo "  openspec-update-global     - Update OpenSpec global tool artifacts"
    @echo "  openspec-bootstrap-global [tools={{openspec_tools_default}}] - Configure + init + update"
    @echo "  openspec-status            - Show OpenSpec config and artifact path status"
    @echo "  pkg-search <query>         - Search for packages"
    @echo "  update <input>             - Update specific flake input"
    @echo ""
    @echo "💡 Pro Tips:"
    @echo "  • Common workflow: just check → just build → just rebuild"
    @echo "  • Use trace=true for detailed error debugging"
    @echo "  • Run 'just clean' regularly to free disk space"

# === Development Commands ===
# Fast syntax validation without building
[group('dev')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔍 Validating flake configuration..."
    nix flake check --show-trace

# Fast check of changed nix files only
[group('dev')]
check-diff:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⚡ Checking changed nix files..."

    # Get changed .nix files (working tree + staged)
    changed_files=$(git diff --name-only HEAD 2>/dev/null | grep '\.nix$' || true)
    staged_files=$(git diff --cached --name-only 2>/dev/null | grep '\.nix$' || true)
    all_changed=$(echo -e "$changed_files\n$staged_files" | sort | uniq | grep -v '^$' || true)

    if [[ -z "$all_changed" ]]; then
        echo "✅ No changed .nix files"
        exit 0
    fi

    echo "📁 Changed files:"
    echo "$all_changed" | sed 's/^/  /'

    # Quick syntax check on each file
    echo "🔍 Syntax check..."
    failed_files=""
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            if ! nix-instantiate --parse "$file" >/dev/null 2>&1; then
                failed_files="$failed_files$file\n"
            fi
        fi
    done <<< "$all_changed"

    if [[ -n "$failed_files" ]]; then
        echo "❌ Syntax errors in:"
        echo -e "$failed_files" | sed 's/^/  /'
        exit 1
    fi

    echo "✅ All checks passed"

# Dry run build test
[group('dev')]
test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Testing build (dry run)..."
    sudo nixos-rebuild dry-build --fast --impure --flake {{host_flake}}

# Dry run build test with staged changes
[group('dev')]
test-staged:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🧪 Staging all changes and testing build (dry run)..."
    git add -A
    just test

# Development rebuild with optional trace
[group('dev')]
build trace="false":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{trace}}" == "true" ]]; then
        echo "🔧 Development rebuild with trace..."
        just clean-full
        sudo nixos-rebuild switch --fast --impure --flake {{host_flake}} --show-trace 2>&1 | tee {{trace_log}}
    else
        echo "🔧 Development rebuild..."
        sudo nixos-rebuild switch --fast --impure --flake {{host_flake}}
    fi

# Development rebuild with staged changes
[group('dev')]
build-staged trace="false":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🔧 Staging all changes and running development rebuild..."
    git add -A
    just build trace="{{trace}}"

# === Production Commands ===
# Production rebuild with bootloader
[group('prod')]
rebuild trace="false":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{trace}}" == "true" ]]; then
        echo "🚀 Production rebuild with trace..."
        sudo nixos-rebuild switch --impure --flake {{host_flake}} --show-trace
    else
        echo "🚀 Production rebuild..."
        sudo nixos-rebuild switch --impure --flake {{host_flake}}
    fi

# Production rebuild with staged changes
[group('prod')]
rebuild-staged trace="false":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🚀 Staging all changes and running production rebuild..."
    git add -A
    just rebuild trace="{{trace}}"

# Initial rebuild for Determinate Nix (bootstraps binary cache)
[group('prod')]
init-determinate:
    @echo "🚀 Initial Determinate Nix rebuild (with binary cache bootstrap)..."
    @sudo nixos-rebuild switch --impure --flake {{host_flake}} \
        --option extra-substituters https://install.determinate.systems \
        --option extra-trusted-public-keys "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="

# Rebuild and activate on next boot
[group('prod')]
boot:
    @echo "🥾 Building for next boot..."
    @sudo nixos-rebuild boot --flake {{host_flake}}

# Build VM for testing
[group('dev')]
vm:
    @echo "🖥️  Building VM..."
    @sudo nixos-rebuild build-vm --fast --impure --flake {{host_flake}} --show-trace

# Full system upgrade
[group('prod')]
upgrade trace="false":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⬆️  Upgrading system..."
    cp flake.lock flake.lock-backup-{{timestamp}}
    nix flake update
    if [[ "{{trace}}" == "true" ]]; then
        sudo nixos-rebuild switch --impure --upgrade --flake {{host_flake}} --show-trace
    else
        sudo nixos-rebuild switch --impure --upgrade --flake {{host_flake}}
    fi
    just voxtype-setup

# Update a specific flake input
[group('prod')]
update input:
    @echo "🔄 Updating {{input}}..."
    @nix flake update {{input}}

# === Maintenance Commands ===
# Quick garbage collection (5 days)
[group('maintenance')]
clean:
    @echo "🧹 Cleaning packages older than 5 days..."
    @sudo nix-collect-garbage --delete-older-than 5d

# Full garbage collection
[group('maintenance')]
clean-full:
    @echo "🧹 Full garbage collection..."
    @sudo nix-collect-garbage -d

# Garbage collect older than specified days
[group('maintenance')]
clean-old days:
    @echo "🧹 Cleaning packages older than {{days}} days..."
    @sudo nix-collect-garbage --delete-older-than {{days}}d

# Manual garbage collection (more aggressive than auto - 7 days vs 14)
[group('maintenance')]
gc-auto:
    @echo "🧹 Manual garbage collection (7 days)..."
    @sudo nix-collect-garbage --delete-older-than 7d

# Nuclear garbage collection - maximum cleanup for fresh builds
[group('maintenance')]
gc-nuclear:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "☢️  NUCLEAR GARBAGE COLLECTION"
    echo "================================"
    echo "🗑️  Deleting old system generations..."
    sudo nix-env --delete-generations old --profile /nix/var/nix/profiles/system
    echo ""
    echo "🗑️  Deleting old boot generations..."
    sudo /nix/var/nix/profiles/system/bin/switch-to-configuration boot
    echo ""
    echo "🧹 Running full garbage collection..."
    sudo nix-collect-garbage -d
    echo ""
    echo "🗑️  Clearing nix evaluation cache..."
    rm -rf ~/.cache/nix
    echo ""
    echo "⚡ Optimizing nix store (this may take a while)..."
    nix-store --optimize
    echo ""
    echo "✅ Nuclear cleanup complete!"
    echo "💾 Disk space reclaimed:"
    df -h / | tail -1

# Optimize nix store
[group('maintenance')]
optimize:
    @echo "⚡ Optimizing nix store..."
    @nix-store --optimize

# Update nix database for comma tool
[group('maintenance')]
update-db:
    @echo "🗄️  Updating nix database..."
    @nix run 'nixpkgs#nix-index' --extra-experimental-features 'nix-command flakes'

# Check code health with deadnix and statix
[group('maintenance')]
health:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🏥 Running code health checks..."
    echo ""
    echo "🔍 Checking for unused code with deadnix..."
    deadnix .
    echo ""
    echo "🔍 Running statix linter..."
    fd -e nix --hidden --no-ignore --follow . -x statix check {}
    echo ""
    echo "✅ Code health check complete"

# Lint nix files (all by default, or specify a file/directory)
[group('maintenance')]
lint target=".":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{target}}" == "." ]]; then
        echo "🔍 Linting all nix files..."
        fd -e nix --hidden --no-ignore --follow . -x statix check {}
    else
        echo "🔍 Linting {{target}}..."
        if [[ -f "{{target}}" ]]; then
            # Single file
            statix check "{{target}}"
        elif [[ -d "{{target}}" ]]; then
            # Directory
            fd -e nix --hidden --no-ignore --follow . "{{target}}" -x statix check {}
        else
            echo "❌ Target not found: {{target}}"
            exit 1
        fi
    fi

# Format all nix files
[group('maintenance')]
fmt:
    @echo "✨ Formatting nix files..."
    @nix fmt

# === System Info ===
# Show kernel and boot info
[group('info')]
kernel:
    @echo "🐧 Current kernel:"
    @uname -r
    @echo "📁 Boot entries:"
    @sudo ls /boot/EFI/nixos/ 2>/dev/null || sudo ls /boot/loader/entries/ 2>/dev/null || echo "No boot entries found"

# List all system generations
[group('info')]
generations:
    @echo "📜 System generations:"
    @sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Comprehensive system information
[group('info')]
sysinfo:
    @echo "💻 System Information:"
    @echo "NixOS: $(nixos-version)"
    @echo "Nix: $(nix --version)"
    @nix shell github:NixOS/nixpkgs#nix-info --extra-experimental-features 'nix-command flakes' --command nix-info -m

# List available base16 color schemes for stylix
[group('info')]
themes:
    @echo "🎨 Available base16 themes ($(nix-shell -p base16-schemes --run 'ls /nix/store/*base16-schemes*/share/themes/ | wc -l') total):"
    @nix-shell -p base16-schemes --run 'ls /nix/store/*base16-schemes*/share/themes/ | sed "s/.yaml$//" | sort'

# Show flake metadata
[group('info')]
show:
    @nix flake show

# Show flake info
[group('info')]
info:
    @nix flake metadata

# === Git Commands ===
# Show recent commits (default: 7 days)
[group('git')]
log days="7":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "📜 Commits from last {{days}} days:"
    echo "Total: $(git rev-list --count --since='{{days}} days ago' HEAD)"
    echo "===================="
    git log --since="{{days}} days ago" --pretty=format:"%h - %an: %s (%cr)" --graph

# Hard reset with cleanup
[group('git')]
reset-hard:
    @echo "⚠️  Hard reset with file cleanup..."
    @git fetch
    @git reset --hard HEAD
    @git clean -fd
    @git pull

# Smart sync: detects git state and pushes, resets, or warns as needed
[group('git')]
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
        echo "⚠️  Diverged — local and remote both have commits:"
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
        echo "⬆️  Pushing unpushed commits..."
        git push origin "$current_branch"
        echo "✅ Pushed to origin/$current_branch"

    elif [[ -n "$remote_only" ]]; then
        echo "⬇️  Aligning git state with remote..."
        git reset "origin/$current_branch"
        echo "✅ Git state aligned with origin/$current_branch"

    else
        echo "✅ Already in sync with origin/$current_branch"
    fi

    git status --short

# === Helper Commands ===
# Enhanced package search functionality
[group('helpers')]
pkg-search query:
    @echo "🔍 Searching for packages: {{query}}"
    @nix search nixpkgs {{query}}

# Run a dev shell with packages
[group('helpers')]
shell packages:
    @nix shell nixpkgs#{{packages}}

# Full rebuild cycle with reboot
[group('helpers')]
rebuild-reboot:
    @echo "🔄 Full rebuild cycle..."
    @just clean-full
    @just rebuild
    @just clean-full
    @echo "🔌 Rebooting in 10 seconds... (Ctrl+C to cancel)"
    @sleep 10
    @sudo reboot

# Stage all changes, run rebuild, then unstage (for quick pre-commit verification)
[group('helpers')]
dev-rebuild trace="false":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "⚡ Staging all changes for dev rebuild..."
    git add -A
    trap 'echo "🔁 Unstaging changes..."; git restore --staged .' EXIT
    just rebuild trace="{{trace}}"

# Ensure Voxtype models are downloaded after upgrades
[group('helpers')]
voxtype-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "🎙️  Ensuring Voxtype models are downloaded..."
    voxtype setup --download

# Show config inspection examples
[group('helpers')]
inspect:
    @echo "🔍 Config inspection examples:"
    @echo "nix eval .#nixosConfigurations.{{hostname}}.config.users.users --json"
    @echo "nix eval .#nixosConfigurations.{{hostname}}.options.services --json"

# === OpenSpec Commands ===
[group('helpers')]
openspec-config-path:
    @openspec config path

[group('helpers')]
openspec-config-show:
    @openspec config list
    @echo ""
    @openspec config list --json

[group('helpers')]
openspec-config-all:
    #!/usr/bin/env bash
    set -euo pipefail
    cfg="$(openspec config path)"
    workflows='{{openspec_workflows_all_json}}'
    mkdir -p "$(dirname "$cfg")"

    tmp="$(mktemp)"
    if [[ -f "$cfg" ]] && jq empty "$cfg" >/dev/null 2>&1; then
      jq --argjson workflows "$workflows" \
        '.profile = "custom" | .delivery = "both" | .workflows = $workflows' \
        "$cfg" > "$tmp"
    else
      jq --argjson workflows "$workflows" -n \
        '{featureFlags: {}, profile: "custom", delivery: "both", workflows: $workflows}' \
        > "$tmp"
    fi

    mv "$tmp" "$cfg"
    echo "✅ OpenSpec configured for all workflows"
    openspec config list

[group('helpers')]
openspec-config-core:
    @openspec config profile core
    @openspec config list

[group('helpers')]
openspec-init-global tools=openspec_tools_default:
    #!/usr/bin/env bash
    set -euo pipefail
    tools_value="{{tools}}"
    tools_value="${tools_value#tools=}"
    openspec init --force --tools "$tools_value" "$HOME"

[group('helpers')]
openspec-update-global:
    #!/usr/bin/env bash
    set -euo pipefail
    openspec update --force "$HOME"

[group('helpers')]
openspec-bootstrap-global tools=openspec_tools_default:
    #!/usr/bin/env bash
    set -euo pipefail
    just openspec-config-all
    just openspec-init-global "{{tools}}"
    just openspec-update-global
    just openspec-status

[group('helpers')]
openspec-status:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "OpenSpec config:"
    openspec config list
    echo ""
    echo "Expected global artifact paths:"
    for p in \
      "$HOME/.claude/commands/opsx" \
      "$HOME/.claude/skills" \
      "$HOME/.codex/skills" \
      "$HOME/.codex/prompts" \
      "$HOME/.github/prompts" \
      "$HOME/.gemini/commands/opsx"
    do
      if [[ -e "$p" ]]; then
        echo "  ✅ $p"
      else
        echo "  ❌ $p (missing)"
      fi
    done

# === Workflow Aliases ===
alias c := check
alias d := check-diff
alias t := test
alias b := build
alias r := rebuild
alias up := upgrade
alias gc := clean
alias l := log
alias s := switch
alias id := init-determinate
alias os-init := openspec-init-global
alias os-up := openspec-update-global
alias os-boot := openspec-bootstrap-global
alias os-status := openspec-status

# Rebuild and switch (alias for rebuild)
[group('prod')]
switch:
    @just rebuild
