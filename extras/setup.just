# Post-rebuild setup — manual steps needed after nixos-rebuild
# Run `just setup::all` for repeatable steps, or individual recipes as needed

# Show available setup recipes
default:
    @just --list setup

# === Repeatable Setup (safe to re-run) ===

# Run all repeatable post-rebuild setup steps
[group('setup')]
all:
    @echo "Running all post-rebuild setup..."
    @just setup::gsd
    @just setup::voxtype
    @echo ""
    @echo "All setup complete!"

# Install/update GSD commands, agents, and hooks for Claude Code
[group('setup')]
gsd:
    @echo "Setting up GSD (get-shit-done)..."
    @gsd-install

# Download Voxtype speech models after upgrades
[group('setup')]
voxtype:
    @echo "Ensuring Voxtype models are downloaded..."
    @voxtype setup --download

# === One-Time Setup (run once after first deploy) ===

# Register yepanywhere for remote access from phone
[group('one-time')]
yepanywhere:
    #!/usr/bin/env bash
    set -euo pipefail
    if [ -d "$HOME/.yepanywhere" ] && [ -f "$HOME/.yepanywhere/config.json" ]; then
        echo "Yepanywhere remote access already configured."
        echo "To reconfigure, run: yepanywhere --setup-remote-access --username <user> --password <pass>"
    else
        echo "Setting up yepanywhere remote access..."
        echo "You will be prompted for a username and password."
        read -rp "Username: " user
        read -rsp "Password: " pass
        echo ""
        yepanywhere --setup-remote-access --username "$user" --password "$pass"
        echo "Remote access configured!"
    fi

# Setup K8s MCP service account for Claude Code
[group('one-time')]
k8s-mcp:
    @echo "Setting up Kubernetes MCP service account..."
    @k8s-mcp-setup setup

# === Version Updates ===

# Check all pinned packages for new releases (caches results)
[group('update')]
check-updates:
    @bash scripts/check-pkg-updates.bash

# Update a specific package (prefetch + write to versions.nix)
[group('update')]
update-pkg *args:
    @bash scripts/update-pkg.bash {{args}}
