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

# Parse-check every changed .nix file
#
# `git diff --name-only` emits paths relative to the repo root, but a module
# recipe runs with cwd = extras/, so an unqualified `[[ -f "$file" ]]` never
# matched and the parse loop silently checked nothing while still printing
# "All checks passed". Every path below is anchored on justfile_directory(),
# which resolves to the ROOT justfile's directory even inside a module.
[doc('Parse-check every changed .nix file')]
[group('validation')]
check-diff:
    #!/usr/bin/env bash
    set -euo pipefail
    root="{{justfile_directory()}}"
    echo "Checking changed nix files..."

    changed_files=$(git -C "$root" diff --name-only HEAD 2>/dev/null | grep '\.nix$' || true)
    staged_files=$(git -C "$root" diff --cached --name-only 2>/dev/null | grep '\.nix$' || true)
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
        if [[ -f "$root/$file" ]]; then
            if ! nix-instantiate --parse "$root/$file" >/dev/null 2>&1; then
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
#
# `--impure` is required here for the same reason every other rebuild recipe
# passes it: flake.nix reads ~/.config/nixos-secrets/secrets.json via an
# absolute-path builtins.readFile, which pure evaluation refuses.
[doc('Rebuild and activate on next boot')]
[group('build')]
boot:
    @echo "Building for next boot..."
    @sudo nixos-rebuild boot --impure --flake {{host_flake}}

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
# Update nix database for comma tool
[group('maintenance')]
update-db:
    @echo "Updating nix database..."
    @nix run 'nixpkgs#nix-index' --extra-experimental-features 'nix-command flakes'

# Lint nix files with statix + deadnix (whole repo by default)
#
# Pass a file or directory to narrow it; the default `.` means the whole repo.
# Every path is anchored on justfile_directory() (the ROOT justfile's dir, even
# from a module) because module recipes run with cwd = extras/: the old bare
# `.` only ever reached extras/scripts/nix-to-json.nix, and an explicit
# repo-root-relative target like `modules/apps/cli/foo` resolved to nothing.
# A relative target is tried against cwd first, then the repo root, so both
# `just ref::lint modules/system` from the repo root and an absolute path work.
#
# Runs both linters because .claude/docs/conventions.md requires both, and
# `just health` was the only recipe doing so.
[doc('Lint nix files with statix + deadnix (whole repo by default)')]
[group('maintenance')]
lint target=".":
    #!/usr/bin/env bash
    set -euo pipefail
    root="{{justfile_directory()}}"
    if [[ "{{target}}" == "." ]]; then
        target="$root"
    elif [[ -e "{{target}}" ]]; then
        target="{{target}}"
    elif [[ -e "$root/{{target}}" ]]; then
        target="$root/{{target}}"
    else
        echo "Target not found: {{target}}"
        exit 1
    fi
    echo "Linting $target..."
    if [[ -f "$target" ]]; then
        statix check "$target"
    else
        fd -e nix --hidden --no-ignore --follow . "$target" -x statix check {}
    fi
    deadnix "$target"

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

# Ensure Voxtype models are downloaded after upgrades
[group('helpers')]
voxtype-setup:
    #!/usr/bin/env bash
    set -euo pipefail
    if ! command -v voxtype >/dev/null 2>&1; then
        echo "Voxtype not installed on this host — skipping model download."
        exit 0
    fi
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
#
# Every git call is anchored on justfile_directory() (the ROOT justfile's dir,
# even from a module). `git clean -fd` is the reason: unlike fetch/reset/pull
# it is scoped to cwd, and a module recipe runs with cwd = extras/, so an
# unanchored clean wiped only extras/ while the reset went repo-wide.
[doc('Hard reset with file cleanup (fetch, reset --hard, clean -fd, pull)')]
[group('git')]
reset-hard:
    @echo "Hard reset with file cleanup..."
    @git -C {{justfile_directory()}} fetch
    @git -C {{justfile_directory()}} reset --hard HEAD
    @git -C {{justfile_directory()}} clean -fd
    @git -C {{justfile_directory()}} pull
