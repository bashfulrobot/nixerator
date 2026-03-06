# Web Applications

Declarative web app modules originally created with [web-app-hub](https://github.com/PVermeer/web-app-hub).

## Structure

```
modules/apps/webapps/
├── default.nix          # Auto-imports all webapp modules
├── calendar/
│   ├── default.nix      # NixOS module
│   └── icon.png         # App icon
└── ...
```

## Enable Apps

```nix
apps.webapps = {
  calendar.enable = true;
  clari.enable = true;
  mail.enable = true;
};
```

## Adding New Apps

1. Enable Web App Hub: `apps.gui.web-app-hub.enable = true;`
2. Create web apps in the Web App Hub GUI
3. Run `extract-webapps` -- finds desktop files, copies icons, generates Nix modules
4. Commit the new modules

Icons/logos: <https://brandfetch.com/>

## How It Works

- Desktop file = single source of truth (no dconf, no config files, no database)
- Each module installs a `.desktop` file + icon via home-manager
- Preserves `X-WAH-ID` for compatibility
- Modules are portable across NixOS systems (just need the browser binary)

## extract-webapps Configuration

`NIXERATOR_PATH` defaults to `globals.paths.nixerator`. Override if needed:

```nix
home-manager.users.${globals.user.name} = {
  home.sessionVariables.NIXERATOR_PATH = "/custom/path";
};
```

## Requirements

- Browser installed (e.g. `google-chrome-stable`)
- home-manager configured
- Flatpak support enabled (for Web App Hub)
- `globals.user.name` set
