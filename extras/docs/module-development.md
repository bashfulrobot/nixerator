# Module Development Guide

Guide for creating new modules in nixerator.

## Quick Start

1. Create directory: `modules/apps/cli/APPNAME/`
2. Create `default.nix` with module pattern
3. Enable in host: `apps.cli.APPNAME.enable = true;`
4. Rebuild system

No manual imports needed - auto-discovery handles it!

## Module Template

### Basic CLI App

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
    environment.systemPackages = with pkgs; [
      APPNAME
    ];
  };
}
```

### GUI App with Home-Manager

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.gui.APPNAME;
  username = globals.user.name;
in
{
  options = {
    apps.gui.APPNAME.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable APPNAME.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      APPNAME
    ];

    home-manager.users.${username} = {
      home.file.".config/APPNAME/config.conf".text = ''
        # Configuration here
      '';
    };
  };
}
```

### Suite Module

```nix
{ lib, config, ... }:

let
  cfg = config.suites.SUITENAME;
in
{
  options = {
    suites.SUITENAME.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable SUITENAME suite.";
    };
  };

  config = lib.mkIf cfg.enable {
    apps.cli = {
      git.enable = true;
      helix.enable = true;
    };

    apps.gui = {
      firefox.enable = true;
    };
  };
}
```

## Module Categories

### apps.cli.*

Command-line applications and tools.

**Location**: `modules/apps/cli/APPNAME/default.nix`

**Examples**: git, helix, docker, fish

**Pattern**:
```nix
config.apps.cli.APPNAME.enable = lib.mkOption { ... }
```

### apps.gui.*

Graphical applications.

**Location**: `modules/apps/gui/APPNAME/default.nix`

**Examples**: google-chrome, firefox, vscode, 1password

**Pattern**:
```nix
config.apps.gui.APPNAME.enable = lib.mkOption { ... }
```

### apps.webapps.*

Progressive web applications (from web-app-hub).

**Location**: `modules/apps/webapps/APPNAME/default.nix`

**Examples**: calendar, mail, slack

**Pattern**:
```nix
config.apps.webapps.APPNAME.enable = lib.mkOption { ... }
```

### suites.*

Collections of related modules.

**Location**: `modules/suites/SUITENAME/default.nix`

**Examples**: core, dev, desktop, browsers, webapps

**Pattern**:
```nix
config.suites.SUITENAME.enable = lib.mkOption { ... }
```

### system.*

System-level configuration.

**Location**: `modules/system/FEATURE/default.nix`

**Examples**: ssh, fonts, networking

**Pattern**:
```nix
config.system.FEATURE.enable = lib.mkOption { ... }
```

### dev.*

Development environment configuration.

**Location**: `modules/dev/LANGUAGE/default.nix`

**Examples**: go, rust, python

**Pattern**:
```nix
config.dev.LANGUAGE.enable = lib.mkOption { ... }
```

## Common Patterns

### Using Global Settings

Access global configuration via `globals`:

```nix
{ globals, ... }:
{
  # User info
  globals.user.name          # "dustin"
  globals.user.fullName      # "Dustin Krysak"
  globals.user.email         # "dustin@krysak.com"

  # System settings
  globals.system.timezone    # "America/Vancouver"
  globals.system.locale      # "en_CA.UTF-8"

  # Preferences
  globals.preferences.editor # "hx"
  globals.preferences.shell  # "fish"
}
```

### Package Installation

```nix
# System-wide
environment.systemPackages = with pkgs; [
  package-name
];

# User-specific (home-manager)
home-manager.users.${username} = {
  home.packages = with pkgs; [
    package-name
  ];
};
```

### Config Files

```nix
# System-wide
environment.etc."app/config.conf".text = ''
  setting = value
'';

# User-specific (home-manager)
home-manager.users.${username} = {
  home.file.".config/app/config.conf".text = ''
    setting = value
  '';

  # Or source from file
  home.file.".config/app/config.conf".source = ./config.conf;
};
```

### Services

```nix
# System service
systemd.services.myservice = {
  description = "My Service";
  wantedBy = [ "multi-user.target" ];
  serviceConfig = {
    ExecStart = "${pkgs.myapp}/bin/myapp";
  };
};

# User service (home-manager)
home-manager.users.${username} = {
  systemd.user.services.myservice = {
    Unit = {
      Description = "My User Service";
    };
    Service = {
      ExecStart = "${pkgs.myapp}/bin/myapp";
    };
    Install = {
      WantedBy = [ "default.target" ];
    };
  };
};
```

### Conditional Configuration

```nix
config = lib.mkIf cfg.enable {
  # Multiple conditions
  programs.git = lib.mkIf config.apps.cli.git.enable {
    # ...
  };

  # Nested conditions
  home-manager.users.${username} = lib.mkMerge [
    (lib.mkIf cfg.feature1 {
      # Config for feature1
    })
    (lib.mkIf cfg.feature2 {
      # Config for feature2
    })
  ];
};
```

## Auto-Import System

Modules are automatically discovered and imported by `modules/default.nix`.

### Excluded Directories

These directory names are ignored:
- `disabled/` - Disabled modules
- `build/` - Build artifacts
- `cfg/` - Configuration templates
- `reference/` - Reference implementations

### Adding Custom Exclusions

Edit `lib/autoimport.nix` to add more exclusions:

```nix
defaultExcludes = [
  "disabled"
  "build"
  "cfg"
  "reference"
  "my-custom-exclude"  # Add here
];
```

## Testing Modules

### Syntax Validation

```bash
# Validate a single module
nix-instantiate --parse modules/apps/cli/APPNAME/default.nix

# Validate entire flake
nix flake check
```

### Building Without Activation

```bash
# Build but don't activate
sudo nixos-rebuild build --flake .#HOSTNAME

# Check what would change
sudo nixos-rebuild dry-build --flake .#HOSTNAME
```

### Testing in VM

```bash
# Build and run in VM
nixos-rebuild build-vm --flake .#HOSTNAME
./result/bin/run-*-vm
```

## Best Practices

1. **Single Responsibility**: One module = one app/feature
2. **Default Disabled**: Always set `default = false`
3. **Clear Descriptions**: Write helpful option descriptions
4. **Use Globals**: Reference `globals` instead of hardcoding
5. **Namespace Properly**: Use correct category (cli/gui/webapps/etc.)
6. **Document Complex Logic**: Add comments for non-obvious code
7. **Test Before Committing**: Validate syntax and test builds

## Examples

See existing modules for reference:
- **Simple CLI**: `modules/apps/cli/zoxide/default.nix`
- **GUI with config**: `modules/apps/gui/google-chrome/default.nix`
- **Suite**: `modules/suites/dev/default.nix`
- **System service**: `modules/apps/cli/tailscale/default.nix`
- **Web app**: `modules/apps/webapps/calendar/default.nix`
