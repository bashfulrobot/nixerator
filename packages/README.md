# Local Package Overrides

This directory contains local package overrides that provide newer versions than
what's currently available in nixpkgs.

## Purpose

- Run latest versions immediately without waiting for nixpkgs PR reviews
- Test new versions locally before contributing to nixpkgs
- Maintain packages you use frequently

## Structure

```
packages/
├── README.md                    # This file
├── VERSION-TRACKING.md          # Version tracking and bump process
└── <package-name>/
    └── default.nix              # Package derivation
```

## Current Overrides

- **insomnia** (12.2.0) - API client for GraphQL, REST, WebSockets, etc.
- **helium** (0.7.10.1) - Privacy-focused Chromium-based web browser (beta)

## Usage

Packages are automatically applied via overlay in `lib/mkHost.nix`.

Enable in your host configuration via the module:

```nix
apps.gui.insomnia.enable = true;
```

Or use directly in systemPackages:

```nix
environment.systemPackages = [ pkgs.insomnia ];
```

## Version Management

See [VERSION-TRACKING.md](./VERSION-TRACKING.md) for:
- Complete version bump process
- Tracked package versions
- Maintenance schedule
- Adding new overrides

## Quick Version Bump

```bash
# 1. Check for updates (search for TODO comments)
grep -r "TODO.*Check for new" packages/

# 2. Update package version and hashes in packages/<name>/default.nix

# 3. Test locally
sudo nixos-rebuild switch --flake .#<hostname>

# 4. Submit to nixpkgs (see VERSION-TRACKING.md for full process)
```

## Finding Packages to Update

```bash
# Search for TODO comments about version checks
grep -r "TODO" packages/ | grep -i "check\|version\|release"
```

Set a monthly calendar reminder to run this check!
