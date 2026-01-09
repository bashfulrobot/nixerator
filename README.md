# Nixerator

Modular NixOS configuration with flakes, home-manager, and Hyprland desktop.

## Quick Start

### New System Installation

```bash
# See detailed installation guide
cat extras/docs/bootstrap.txt
```

### Update Existing System

```bash
cd ~/dev/nix/nixerator
sudo nixos-rebuild switch --flake .#HOSTNAME
```

## Common Commands

```bash
# Using justfile
just switch          # Rebuild and switch
just update          # Update flake inputs
just clean           # Garbage collect
just generations     # List generations

# Direct nix commands
sudo nixos-rebuild switch --flake .#HOSTNAME
nix flake update
nix-collect-garbage -d
```

## Configuration

**Global settings**: `settings/globals.nix`
Username, timezone, locale, editor preferences

**Host-specific**: `hosts/HOSTNAME/configuration.nix`
Enable modules via options:

```nix
{
  apps.cli.git.enable = true;
  apps.gui.google-chrome.enable = true;
  suites.dev.enable = true;  # Enable entire suite
}
```

## Documentation

- **[Architecture](extras/docs/architecture.md)** - Directory structure and design principles
- **[Module Development](extras/docs/module-development.md)** - Creating new modules
- **[VM Development](extras/docs/vm-development.md)** - Development VM setup
- **[Web Apps](extras/docs/webapps.md)** - Progressive web application modules
- **[SSH Configuration](extras/docs/ssh.md)** - SSH module and host aliases
- **[Google Chrome](extras/docs/google-chrome.md)** - Chrome with Dark Reader theme
- **[Helper Scripts](extras/docs/helpers.md)** - Utility scripts
- **[Web App Hub](extras/docs/web-app-hub.md)** - PWA creation tool

## Module Categories

```
modules/
├── apps/
│   ├── cli/          # Command-line tools
│   ├── gui/          # Graphical applications
│   └── webapps/      # Progressive web apps
├── suites/           # Grouped module collections
├── system/           # System configuration
└── dev/              # Development environments
```

Enable individually or by suite:

```nix
# Individual apps
apps.cli.git.enable = true;

# Or enable entire suite
suites.dev.enable = true;
```

## Desktop

- The desktop configuration is an external repo for the Hyprland desktop: [bashfulrobot/hyprflake](https://github.com/bashfulrobot/hyprflake)
