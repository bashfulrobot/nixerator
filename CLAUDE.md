# Nixerator - Personal NixOS Configuration

Multi-host NixOS flake with Home Manager, auto-imported modules, suites/archetypes, and git-crypt encrypted secrets.

## Project Structure

```
nixerator/
├── flake.nix              # Flake definition with inputs and host declarations
├── settings/
│   ├── globals.nix        # User info, defaults, preferences
│   └── versions.nix       # Version pins
├── secrets/               # git-crypt encrypted secrets (secrets.json)
├── lib/
│   ├── default.nix        # Library exports
│   ├── mkHost.nix         # Host builder function
│   └── autoimport.nix     # Recursive module auto-importer
├── hosts/                 # Per-host configurations
│   ├── qbert/             # Desktop workstation (AMD GPU)
│   ├── donkeykong/        # ThinkPad T14 laptop
│   ├── nixerator/         # VM development host
│   └── srv/               # Home server
├── modules/
│   ├── archetypes/        # High-level host types (workstation, server)
│   ├── suites/            # Feature bundles (core, dev, browsers, etc.)
│   ├── apps/              # Individual applications (cli/, gui/, webapps/)
│   ├── system/            # System services (ssh, flatpak, cachix)
│   ├── server/            # Server-specific (kvm, nfs, restic)
│   └── dev/               # Development environments (go)
├── packages/              # Custom package overrides
└── extras/
    ├── docs/              # Detailed documentation
    └── helpers/           # Setup scripts
```

## Hosts

| Host | Type | GPU | Features |
|------|------|-----|----------|
| qbert | Desktop | AMD | bcachefs, disko, USB wakeup, Wake-on-LAN |
| donkeykong | Laptop | Intel | LUKS, disko, nixos-hardware ThinkPad T14 |
| nixerator | VM | - | virtiofs shared folders |
| srv | Server | - | Static IP, KVM, NFS, Restic backups |

## Quick Commands

```bash
# Rebuild current host
sudo nixos-rebuild switch --flake .#$(hostname)

# Rebuild specific host
sudo nixos-rebuild switch --flake .#qbert

# Check flake
nix flake check

# Update all inputs
nix flake update

# Format code
nixpkgs-fmt .
```

## Key Concepts

- **Archetypes** - High-level host profiles (`archetypes.workstation.enable = true`)
- **Suites** - Feature bundles enabling related modules (`suites.dev.enable = true`)
- **Auto-import** - Modules in `modules/` are auto-discovered (excludes `disabled/`, `build/`, `cfg/`)
- **Globals** - Shared config in `settings/globals.nix` (user, locale, preferences)
- **Secrets** - git-crypt encrypted `secrets/secrets.json`

## Detailed Documentation

For in-depth guides, read these files:

- `extras/docs/modules.md` - Module system, suites, archetypes, autoimport
- `extras/docs/hosts.md` - Host configurations and hardware details
- `extras/docs/secrets.md` - git-crypt setup and secrets management
- `extras/docs/adding-hosts.md` - How to add a new host
- `extras/docs/adding-modules.md` - How to add new modules/apps

## External Dependencies

- [hyprflake](https://github.com/bashfulrobot/hyprflake) - Hyprland desktop environment
- [stylix](https://github.com/nix-community/stylix) - System-wide theming
- [disko](https://github.com/nix-community/disko) - Declarative disk partitioning
- [home-manager](https://github.com/nix-community/home-manager) - User environment management

---

## Maintaining This Documentation

This CLAUDE.md uses a modular documentation pattern to reduce token consumption while keeping detailed information accessible.

### When to Add to CLAUDE.md Directly

Add content here when it is:

- **Essential context** needed for most tasks (project structure, hosts overview)
- **Brief** - fits in a few lines without detailed examples
- **Frequently referenced** - used in majority of conversations

### When to Create a Separate Doc in `extras/docs/`

Create a new file when the content is:

- **Detailed reference material** - comprehensive options, many examples
- **Topic-specific** - only relevant when working on that specific area
- **Long-form** - more than ~20-30 lines of content

### How to Add a New Documentation File

1. Create the file in `extras/docs/` with a descriptive name (e.g., `networking.md`)
2. Add a brief link in the "Detailed Documentation" section above
3. Use clear headings and code examples in the new file

### Guidelines

- Keep CLAUDE.md under ~100 lines of actual content
- Each `extras/docs/` file should be self-contained
- Use descriptive link text so the LLM knows when to consult each doc
- Prefer showing "what" in CLAUDE.md, detailed "how" in extras/docs/
