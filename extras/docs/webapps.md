# Web Applications Module

This module provides declarative configuration for web applications originally created with [web-app-hub](https://github.com/PVermeer/web-app-hub).

## Structure

Each web app is stored as a separate module:

```
webapps/
├── default.nix          # Auto-imports all webapp modules
├── calendar/
│   ├── default.nix      # NixOS module
│   └── icon.png         # App icon
├── clari/
│   ├── default.nix
│   └── icon.png
└── ...
```

## Icons/Logos

- Most times you can find logos at <https://brandfetch.com/>

## Usage

### Individual Apps

Enable specific apps in your configuration:

```nix
{
  apps.webapps = {
    calendar.enable = true;
    clari.enable = true;
    mail.enable = true;
  };
}
```

### Suite

Enable all web apps at once:

```nix
{
  suites.webapps.enable = true;
}
```

## Adding New Apps

1. Enable the web-app-hub module to get the extraction command:

   ```nix
   apps.gui.web-app-hub.enable = true;
   ```

2. Create your web apps in Web App Hub GUI

3. Run the extraction command:

   ```bash
   extract-webapps
   ```

4. The script will automatically:
   - Find all web-app-hub desktop files
   - Copy icons to the appropriate directories
   - Generate Nix modules with proper structure

5. Commit the new modules to the repository

## How It Works

Each module:

- Installs a desktop file to `~/.local/share/applications/`
- Includes the app icon from the Nix store
- Preserves the original X-WAH-ID for compatibility
- Uses home-manager for user-specific installation

### Web App Hub Design

According to the web-app-hub developer:

> All information and settings are saved in the *.desktop file in ~/.local/share/applications. It's the only thing this app reads out. There are no hidden settings, config files or dconf settings. Just copying these files is enough to back them up.

This means:

- **Single source of truth**: The `.desktop` file contains everything
- **No hidden configs**: No dconf, no config files, no database
- **Simple backup**: Just the `.desktop` files (+ icons)
- **Filename stability**: Only the filename might change with browser updates (unlikely in near future)

## Portability

The X-WAH-ID is just a unique identifier - it has no system dependencies. These modules will work identically across all NixOS systems, as long as the browser binary is available.

Since all settings are embedded in the `.desktop` file, you can:

- Copy modules between systems seamlessly
- Version control everything (no external state)
- Rebuild identical configurations anywhere

## Requirements

- Browser must be installed (e.g., `google-chrome-stable`)
- home-manager configured
- `globals.user.name` set in your configuration

## Web App Hub Application

To create new web apps, enable the Web App Hub application:

```nix
{
  apps.gui.web-app-hub.enable = true;
}
```

This will:

- Install the Web App Hub flatpak
- Add the `extract-webapps` command to your PATH
- Set up the environment for extraction
