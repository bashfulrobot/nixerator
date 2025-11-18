# Default recipe to display help
default:
    @just --list

# Rebuild and switch NixOS configuration
switch:
    sudo nixos-rebuild switch --flake .#$(hostname)

# Rebuild NixOS and activate on next boot (doesn't affect current session)
boot:
    sudo nixos-rebuild boot --flake .#$(hostname)

# Test NixOS configuration without switching (temporary until reboot)
test:
    sudo nixos-rebuild test --flake .#$(hostname)

# Build NixOS configuration without activating
build:
    sudo nixos-rebuild build --flake .#$(hostname)

# Check flake for errors without building
check:
    nix flake check

# Update flake inputs (nixpkgs, home-manager, etc.)
update:
    nix flake update

# Update a specific flake input
update-input input:
    nix flake lock --update-input {{input}}

# Show flake metadata
show:
    nix flake show

# Show flake outputs
info:
    nix flake metadata

# Home Manager is integrated as a NixOS module
# Use 'just switch' or 'just test' to rebuild both NixOS and Home Manager

# Garbage collect old generations (delete)
clean:
    sudo nix-collect-garbage -d

# Garbage collect generations older than specified days
clean-old days:
    sudo nix-collect-garbage --delete-older-than {{days}}d

# List all system generations
generations:
    sudo nix-env --list-generations --profile /nix/var/nix/profiles/system

# Optimize nix store (deduplicate)
optimize:
    nix-store --optimize

# Format all nix files
fmt:
    nix fmt

# Run a dev shell with packages available
shell packages:
    nix shell nixpkgs#{{packages}}

# Search for a package
search package:
    nix search nixpkgs {{package}}

# Show system info
sysinfo:
    nixos-version
    nix --version
