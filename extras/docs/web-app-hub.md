# Web App Hub Module

This module provides the [Web App Hub](https://github.com/PVermeer/web-app-hub) application for creating progressive web apps, along with utilities to extract them into declarative Nix modules.

## What It Provides

1. **Web App Hub Flatpak** - GUI application for creating web apps
2. **`extract-webapps` command** - Utility to convert web apps into Nix modules

## Usage

Enable in your configuration:

```nix
{
  apps.gui.web-app-hub.enable = true;
}
```

## Creating Web Apps

1. Launch Web App Hub from your application launcher
2. Create web apps using the GUI
3. Run `extract-webapps` in your terminal
4. New Nix modules will be created in `modules/apps/webapps/`
5. Commit the modules to version control

## Configuration

The extraction script uses `NIXERATOR_PATH` environment variable to locate your nixerator repository. By default, it's set to `/home/$USER/dev/nix/nixerator`.

Override if needed:

```nix
{
  home-manager.users.${username} = {
    home.sessionVariables = {
      NIXERATOR_PATH = "/path/to/your/nixerator";
    };
  };
}
```

## How It Works

The `extract-webapps` command:
- Scans `~/.local/share/applications/` for web-app-hub desktop files
- Copies icons from `~/.var/app/org.pvermeer.WebAppHub/data/`
- Generates Nix modules in `modules/apps/webapps/<app-name>/`
- Each module includes the desktop file and icon

## Requirements

- Flatpak support enabled in your system
- home-manager configured
- A browser installed (Chrome, Firefox, etc.)
