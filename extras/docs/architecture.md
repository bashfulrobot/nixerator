# Nixerator Architecture

Modular NixOS configuration with flakes, home-manager, and auto-imported modules.

## Directory Structure

```
nixerator/
├── flake.nix              # Flake inputs and outputs
├── flake.lock             # Locked dependency versions
├── settings/
│   ├── globals.nix        # Global settings (user, timezone, editor, etc.)
│   └── versions.nix       # Version pinning
├── lib/
│   ├── default.nix        # Library exports
│   ├── mkHost.nix         # Host builder function
│   └── autoimport.nix     # Auto-import helper
├── modules/
│   ├── default.nix        # Auto-imports all modules
│   ├── apps/
│   │   ├── cli/           # CLI applications
│   │   │   ├── git/
│   │   │   ├── helix/
│   │   │   └── ...
│   │   ├── gui/           # GUI applications
│   │   │   ├── google-chrome/
│   │   │   ├── web-app-hub/
│   │   │   └── ...
│   │   └── webapps/       # Web applications (PWAs)
│   ├── dev/               # Development tools
│   │   ├── go/
│   │   └── ...
│   ├── suites/            # Grouped module collections
│   │   ├── core/          # Essential system utilities
│   │   ├── dev/           # Development environment
│   │   ├── desktop/       # Desktop environment
│   │   ├── browsers/      # Web browsers
│   │   ├── webapps/       # All web applications
│   │   └── ...
│   └── system/            # System-level configuration
│       ├── ssh/
│       ├── fonts/
│       └── ...
├── hosts/                 # Per-host configurations
│   ├── nixerator/         # VM development host
│   │   ├── configuration.nix
│   │   ├── hardware-configuration.nix
│   │   └── home.nix
│   └── donkeykong/        # Encrypted desktop workstation
│       ├── configuration.nix
│       ├── hardware-configuration.nix
│       ├── disko.nix      # Disk partitioning
│       ├── boot.nix       # LUKS encryption + hibernation
│       └── home.nix       # Home-manager config
└── extras/
    ├── docs/              # Documentation
    └── helpers/           # Utility scripts
```

## Key Concepts

### Auto-Import Pattern

Modules are automatically discovered and imported:

```nix
# modules/default.nix
{ lib }:
let
  autoImportLib = import ../lib/autoimport.nix { inherit lib; };
in
autoImportLib.simpleAutoImport ./.
```

This recursively imports all `*.nix` files except:
- `default.nix` itself
- Files in `disabled/`, `build/`, `cfg/`, `reference/` directories

### Module Structure

Every module follows this pattern:

```nix
{ lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.APPNAME;
in
{
  options = {
    apps.cli.APPNAME.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable APPNAME.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Configuration here
  };
}
```

### Namespacing

Modules are organized by category:

- `apps.cli.*` - Command-line applications
- `apps.gui.*` - Graphical applications
- `apps.webapps.*` - Progressive web apps
- `suites.*` - Module collections
- `system.*` - System-level settings
- `dev.*` - Development tools

### Suites

Suites group related modules for easy enablement:

```nix
# modules/suites/dev/default.nix
{
  config = lib.mkIf cfg.enable {
    apps.cli = {
      git.enable = true;
      helix.enable = true;
      docker.enable = true;
    };
    dev.go.enable = true;
  };
}
```

Usage:

```nix
# In host configuration
suites.dev.enable = true;  # Enables all dev tools
```

## Host Configuration

### mkHost Function

Hosts are built using `lib.mkHost`:

```nix
# flake.nix
outputs = { self, nixpkgs, ... }@inputs: {
  nixosConfigurations = {
    donkeykong = lib.mkHost {
      hostname = "donkeykong";
      system = "x86_64-linux";
      # Additional host-specific settings
    };
  };
};
```

### Configuration Files

Each host has:

1. **configuration.nix** - Main system configuration, module enablement
2. **hardware-configuration.nix** - Auto-generated hardware settings
3. **home.nix** - Home-manager user configuration
4. **disko.nix** (optional) - Declarative disk partitioning
5. **boot.nix** (optional) - Boot configuration (LUKS, hibernation, etc.)

## Global Settings

`settings/globals.nix` contains shared configuration:

```nix
{
  user = {
    name = "dustin";
    fullName = "Dustin Krysak";
    email = "dustin@krysak.com";
  };
  system = {
    timezone = "America/Vancouver";
    locale = "en_CA.UTF-8";
  };
  preferences = {
    editor = "hx";
    shell = "fish";
  };
}
```

Access in modules via `globals.user.name`, etc.

## Flake Inputs

External dependencies are managed in `flake.nix`:

```nix
inputs = {
  nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
  home-manager.url = "github:nix-community/home-manager";
  hyprflake.url = "github:bashfulrobot/hyprflake";
  # ...
};
```

## Design Principles

1. **Modular**: Everything is a module with enable option
2. **Declarative**: Configuration as code, version controlled
3. **Composable**: Combine modules via suites or individual enables
4. **Discoverable**: Auto-import pattern eliminates manual imports
5. **Portable**: Same configuration works across systems
6. **Namespaced**: Clear organization by category
