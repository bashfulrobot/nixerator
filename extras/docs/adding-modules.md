# Adding New Modules

Guide to adding new applications and modules to nixerator.

## Module Types

| Type | Path | Purpose |
|------|------|---------|
| CLI App | `modules/apps/cli/<name>/` | Command-line applications |
| GUI App | `modules/apps/gui/<name>/` | Graphical applications |
| Web App | `modules/apps/webapps/<name>/` | Web app desktop entries |
| Suite | `modules/suites/<name>/` | Feature bundles |
| System | `modules/system/<name>/` | System services |
| Server | `modules/server/<name>/` | Server-specific features |
| Dev | `modules/dev/<name>/` | Development environments |

## Adding a CLI Application

### Step 1: Create Module Directory

```bash
mkdir -p modules/apps/cli/myapp
```

### Step 2: Create default.nix

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.myapp;
  username = globals.user.name;
in
{
  options = {
    apps.cli.myapp.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable myapp CLI tool.";
    };
  };

  config = lib.mkIf cfg.enable {
    # System-level packages
    environment.systemPackages = [ pkgs.myapp ];

    # Or Home Manager configuration
    home-manager.users.${username} = {
      programs.myapp = {
        enable = true;
        # Configuration options...
      };
    };
  };
}
```

### Step 3: Enable in Suite or Host

In a suite (`modules/suites/dev/default.nix`):

```nix
config = lib.mkIf cfg.enable {
  apps.cli.myapp.enable = true;
};
```

Or in a host (`hosts/qbert/modules.nix`):

```nix
{
  apps.cli.myapp.enable = true;
}
```

## Adding a GUI Application

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.gui.myguiapp;
  username = globals.user.name;
in
{
  options.apps.gui.myguiapp.enable = lib.mkEnableOption "MyGuiApp";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.myguiapp ];

    # Optional: Desktop file customization
    home-manager.users.${username} = {
      xdg.desktopEntries.myguiapp = {
        name = "My GUI App";
        exec = "${pkgs.myguiapp}/bin/myguiapp";
        icon = "myguiapp";
        categories = [ "Utility" ];
      };
    };
  };
}
```

## Adding a Web App

Web apps are desktop entries that launch a browser in app mode:

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.webapps.mywebapp;
  username = globals.user.name;
in
{
  options.apps.webapps.mywebapp.enable = lib.mkEnableOption "My Web App";

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      xdg.desktopEntries.mywebapp = {
        name = "My Web App";
        exec = "${pkgs.google-chrome}/bin/google-chrome-stable --app=https://mywebapp.com";
        icon = "web-browser";
        categories = [ "Network" "WebBrowser" ];
      };
    };
  };
}
```

## Adding a Suite

```nix
{ lib, config, ... }:

let
  cfg = config.suites.mysuite;
in
{
  options.suites.mysuite.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable my suite with related tools.";
  };

  config = lib.mkIf cfg.enable {
    # Enable component modules
    apps.cli.tool1.enable = true;
    apps.cli.tool2.enable = true;
    apps.gui.app1.enable = true;
  };
}
```

## Adding to an Archetype

Edit `modules/archetypes/workstation/default.nix`:

```nix
config = lib.mkIf cfg.enable {
  suites = {
    # ... existing suites ...
    mysuite.enable = true;  # Add your suite
  };
};
```

## Module with Home Manager Programs

For applications with `programs.<name>` in Home Manager:

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.myapp;
  username = globals.user.name;
in
{
  options.apps.cli.myapp.enable = lib.mkEnableOption "myapp";

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      programs.myapp = {
        enable = true;
        package = pkgs.myapp;

        settings = {
          theme = "dark";
          # ...
        };
      };
    };
  };
}
```

## Module with Custom Options

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.myapp;
  username = globals.user.name;
in
{
  options.apps.cli.myapp = {
    enable = lib.mkEnableOption "myapp";

    extraConfig = lib.mkOption {
      type = lib.types.lines;
      default = "";
      description = "Extra configuration for myapp";
    };

    host = lib.mkOption {
      type = lib.types.attrsOf lib.types.bool;
      default = {};
      description = "Per-host enable flags";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${username} = {
      home.file.".config/myapp/config" = lib.mkIf (cfg.extraConfig != "") {
        text = cfg.extraConfig;
      };
    };
  };
}
```

## Module with Secrets

```nix
{ lib, config, secrets, ... }:

let
  cfg = config.apps.cli.myapp;
in
{
  options.apps.cli.myapp.enable = lib.mkEnableOption "myapp";

  config = lib.mkIf cfg.enable {
    # Only configure if secret exists
    someService = lib.optionalAttrs (secrets.myapp.apiKey or null != null) {
      apiKey = secrets.myapp.apiKey;
    };
  };
}
```

## Excluding from Auto-Import

To disable a module temporarily without deleting it:

1. Create a `disabled/` subdirectory
2. Move the module there

```bash
mkdir -p modules/apps/cli/myapp/disabled
mv modules/apps/cli/myapp/default.nix modules/apps/cli/myapp/disabled/
```

The `disabled/` directory is excluded from auto-import.

## Testing a New Module

1. Enable in a host's `modules.nix`
2. Build without switching:

```bash
nixos-rebuild build --flake .#hostname
```

3. If successful, switch:

```bash
sudo nixos-rebuild switch --flake .#hostname
```

## Checklist

- [ ] Created module directory in appropriate location
- [ ] Created `default.nix` with options and config
- [ ] Added to relevant suite or host modules.nix
- [ ] Tested with `nixos-rebuild build`
- [ ] Documented any secrets requirements
