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
  options.apps.cli.APPNAME.enable = lib.mkEnableOption "APPNAME";

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
in
{
  options.apps.gui.APPNAME.enable = lib.mkEnableOption "APPNAME";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      APPNAME
    ];

    home-manager.users.${globals.user.name} = {
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
  options.suites.SUITENAME.enable = lib.mkEnableOption "SUITENAME suite";

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
options.apps.cli.APPNAME.enable = lib.mkEnableOption "APPNAME"
```

### apps.gui.*

Graphical applications.

**Location**: `modules/apps/gui/APPNAME/default.nix`

**Examples**: google-chrome, firefox, vscode, 1password

**Pattern**:
```nix
options.apps.gui.APPNAME.enable = lib.mkEnableOption "APPNAME"
```

### apps.webapps.*

Progressive web applications (from web-app-hub).

**Location**: `modules/apps/webapps/APPNAME/default.nix`

**Examples**: calendar, mail, slack

**Pattern**:
```nix
options.apps.webapps.APPNAME.enable = lib.mkEnableOption "APPNAME"
```

### suites.*

Collections of related modules.

**Location**: `modules/suites/SUITENAME/default.nix`

**Examples**: core, dev, desktop, browsers, webapps

**Pattern**:
```nix
options.suites.SUITENAME.enable = lib.mkEnableOption "SUITENAME suite"
```

### system.*

System-level configuration.

**Location**: `modules/system/FEATURE/default.nix`

**Examples**: ssh, apple-fonts, networking

**Pattern**:
```nix
options.system.FEATURE.enable = lib.mkEnableOption "FEATURE"
```

### dev.*

Development environment configuration.

**Location**: `modules/dev/LANGUAGE/default.nix`

**Examples**: go, rust, python

**Pattern**:
```nix
options.dev.LANGUAGE.enable = lib.mkEnableOption "LANGUAGE"
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
  globals.user.email         # "dustin@bashfulrobot.com"

  # System settings
  globals.defaults.timeZone    # "America/Vancouver"
  globals.defaults.locale      # "en_US.UTF-8"

  # Preferences
  globals.preferences.editor # "helix"
  globals.preferences.shell  # "fish"

  # Common paths
  globals.paths.devRoot     # "<home>/dev"
  globals.paths.nixerator   # "<home>/dev/nix/nixerator"
}
```

### Module-Local Packages (build/)

For custom packages used by a module, place the derivation in a sibling `build/` directory and call it from the module:

```nix
{ lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.myapp;
  myapp = pkgs.callPackage ./build { };
in
{
  options.apps.cli.myapp.enable = lib.mkEnableOption "myapp";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ myapp ];
  };
}
```

### Package Installation

```nix
# System-wide
environment.systemPackages = with pkgs; [
  package-name
];

# User-specific (home-manager)
home-manager.users.${globals.user.name} = {
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
home-manager.users.${globals.user.name} = {
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
home-manager.users.${globals.user.name} = {
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
  home-manager.users.${globals.user.name} = lib.mkMerge [
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
- `build/` - Build scripts and module-local package derivations
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
nix flake check --show-trace
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
2. **Prefer mkEnableOption**: Use `lib.mkEnableOption` for `enable` toggles
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
