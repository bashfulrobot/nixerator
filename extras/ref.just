# Reference recipes — rarely used, accessed via `just ref::<recipe>`

# Show available reference recipes
default:
    @just --list ref

# === Variables ===
hostname := `hostname`
host_flake := ".#" + hostname
# === Validation ===
# Full flake validation
[group('validation')]
check:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Validating flake configuration..."
    nix flake check --show-trace

# Check changed nix files only
[group('validation')]
check-diff:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Checking changed nix files..."

    changed_files=$(git diff --name-only HEAD 2>/dev/null | grep '\.nix$' || true)
    staged_files=$(git diff --cached --name-only 2>/dev/null | grep '\.nix$' || true)
    all_changed=$(echo -e "$changed_files\n$staged_files" | sort | uniq | grep -v '^$' || true)

    if [[ -z "$all_changed" ]]; then
        echo "No changed .nix files"
        exit 0
    fi

    echo "Changed files:"
    echo "$all_changed" | sed 's/^/  /'

    echo "Syntax check..."
    failed_files=""
    while IFS= read -r file; do
        if [[ -f "$file" ]]; then
            if ! nix-instantiate --parse "$file" >/dev/null 2>&1; then
                failed_files="$failed_files$file\n"
            fi
        fi
    done <<< "$all_changed"

    if [[ -n "$failed_files" ]]; then
        echo "Syntax errors in:"
        echo -e "$failed_files" | sed 's/^/  /'
        exit 1
    fi

    echo "All checks passed"

# Dry run build test
[group('validation')]
test:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Testing build (dry run)..."
    sudo nixos-rebuild dry-build --fast --impure --flake {{host_flake}}

# === Build Variants ===
# Rebuild and activate on next boot
[group('build')]
boot:
    @echo "Building for next boot..."
    @sudo nixos-rebuild boot --flake {{host_flake}}

# Build VM for testing
[group('build')]
vm:
    @echo "Building VM..."
    @sudo nixos-rebuild build-vm --fast --impure --flake {{host_flake}} --show-trace

# Initial rebuild for Determinate Nix (bootstraps binary cache)
[group('build')]
init-determinate:
    @echo "Initial Determinate Nix rebuild (with binary cache bootstrap)..."
    @sudo nixos-rebuild switch --impure --flake {{host_flake}} \
        --option extra-substituters https://install.determinate.systems \
        --option extra-trusted-public-keys "cache.flakehub.com-3:hJuILl5sVK4iKm86JzgdXW12Y2Hwd5G07qKtHTOcDCM="

# Full rebuild cycle with reboot
[group('build')]
rebuild-reboot:
    @echo "Full rebuild cycle..."
    @sudo nix-collect-garbage -d
    @just rebuild
    @sudo nix-collect-garbage -d
    @echo "Rebooting in 10 seconds... (Ctrl+C to cancel)"
    @sleep 10
    @sudo reboot

# === System Info ===
# Show kernel and boot info
[group('info')]
kernel:
    @echo "Current kernel:"
    @uname -r
    @echo "Boot entries:"
    @sudo ls /boot/EFI/nixos/ 2>/dev/null || sudo ls /boot/loader/entries/ 2>/dev/null || echo "No boot entries found"

# List all system generations
[group('info')]
generations:
    @echo "System generations:"
    @sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Comprehensive system information
[group('info')]
sysinfo:
    @echo "System Information:"
    @echo "NixOS: $(nixos-version)"
    @echo "Nix: $(nix --version)"
    @nix shell github:NixOS/nixpkgs#nix-info --extra-experimental-features 'nix-command flakes' --command nix-info -m

# List available base16 color schemes for stylix
[group('info')]
themes:
    @echo "Available base16 themes ($(nix-shell -p base16-schemes --run 'ls /nix/store/*base16-schemes*/share/themes/ | wc -l') total):"
    @nix-shell -p base16-schemes --run 'ls /nix/store/*base16-schemes*/share/themes/ | sed "s/.yaml$//" | sort'

# Show flake outputs
[group('info')]
show:
    @nix flake show

# Show flake metadata
[group('info')]
info:
    @nix flake metadata

# === Maintenance ===
# Optimize nix store
[group('maintenance')]
optimize:
    @echo "Optimizing nix store..."
    @nix-store --optimize

# Update nix database for comma tool
[group('maintenance')]
update-db:
    @echo "Updating nix database..."
    @nix run 'nixpkgs#nix-index' --extra-experimental-features 'nix-command flakes'

# Lint nix files (all by default, or specify a file/directory)
[group('maintenance')]
lint target=".":
    #!/usr/bin/env bash
    set -euo pipefail
    if [[ "{{target}}" == "." ]]; then
        echo "Linting all nix files..."
        fd -e nix --hidden --no-ignore --follow . -x statix check {}
    else
        echo "Linting {{target}}..."
        if [[ -f "{{target}}" ]]; then
            statix check "{{target}}"
        elif [[ -d "{{target}}" ]]; then
            fd -e nix --hidden --no-ignore --follow . "{{target}}" -x statix check {}
        else
            echo "Target not found: {{target}}"
            exit 1
        fi
    fi

# === Helpers ===
# Search for packages
[group('helpers')]
pkg-search query:
    @echo "Searching for packages: {{query}}"
    @nix search nixpkgs {{query}}

# Run a dev shell with packages
[group('helpers')]
shell packages:
    @nix shell nixpkgs#{{packages}}

# Show config inspection examples
[group('helpers')]
inspect:
    @echo "Config inspection examples:"
    @echo "nix eval .#nixosConfigurations.{{hostname}}.config.users.users --json"
    @echo "nix eval .#nixosConfigurations.{{hostname}}.options.services --json"

# Ensure Voxtype models are downloaded after upgrades
[group('helpers')]
voxtype-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Ensuring Voxtype models are downloaded..."
    voxtype setup --download

# === Git ===
# Show recent commits (default: 7 days)
[group('git')]
log days="7":
    #!/usr/bin/env bash
    set -euo pipefail
    echo "Commits from last {{days}} days:"
    echo "Total: $(git rev-list --count --since='{{days}} days ago' HEAD)"
    echo "===================="
    git log --since="{{days}} days ago" --pretty=format:"%h - %an: %s (%cr)" --graph

# Hard reset with cleanup
[group('git')]
reset-hard:
    @echo "Hard reset with file cleanup..."
    @git fetch
    @git reset --hard HEAD
    @git clean -fd
    @git pull
