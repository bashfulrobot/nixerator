# Post-rebuild setup — manual steps needed after nixos-rebuild
# Run individual recipes as needed: `just setup::<recipe>`

# Show available setup recipes
default:
    @just --list setup

# === Repeatable Setup (safe to re-run) ===
#
# This section is currently empty; both of its recipes were removed and the
# reasons are kept here so neither gets reintroduced by accident.
#
# `voxtype` was a byte-identical duplicate of `ref::voxtype-setup`, and that
# is the copy the rebuild chain actually calls (`upgrade` and `quiet-upgrade`
# both run `just ref::voxtype-setup`). Run `just ref::voxtype-setup` by hand
# if you ever need it standalone.
#
# `gsd` was disabled 2026-07-31 because `gsd-install` no longer exists.
# Nothing under modules/ provides it (the only remaining `gsd` reference in
# the tree is a `gsd-*` filename skip in cfg/scripts/capture-sync.py, which is
# a filter, not a provider), so it failed on every run. Kept as a note rather
# than deleted outright in case the tool is reintroduced:
#
# [group('setup')]
# gsd:
#     @echo "Setting up GSD (get-shit-done)..."
#     @gsd-install
#
# With both gone, the `all` aggregator had no working steps left, so it was
# removed too.

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
