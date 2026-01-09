# Dark Reader Theme

This directory contains the Dark Reader theme generation docs that uses your Stylix colors.

## Usage

The Dark Reader theme is automatically generated and placed at `~/.config/darkreader/settings.json` when you build your NixOS configuration with the `apps.gui.google-chrome` module enabled.

### Automatic Setup

After rebuilding your NixOS configuration, the Dark Reader settings file will be available at:

```bash
~/.config/darkreader/settings.json
```

### Importing into Chrome

1. Open Google Chrome
2. Install the Dark Reader extension if not already installed
3. Click the Dark Reader extension icon
4. Go to Settings (⚙️) → More → All Settings -> Advanced -> Import Settings
5. Select `~/.config/darkreader/settings.json`

### Color Mapping

The theme uses your Stylix colors:

- **Dark Background**: base00 (main background color)
- **Dark Text**: base05 (main text color)
- **Light Background**: base07 (light mode background)
- **Light Text**: base02 (light mode text)

Fallback values are used if Stylix is not enabled.

### Configuration Details

The generated theme includes:

- System-based automation (follows system dark/light mode)
- Custom themes for specific sites:
    - `us2.app.sysdig.com` (mode 0, brightness 80%)
    - `calendar.google.com` (mode 1, brightness 100%)
- PDF support enabled
- Context menus enabled
- Settings and site fixes sync enabled

### Customization

To modify the configuration:

1. Edit the `mkDarkReaderConfig` function in `default.nix` to change theme settings or add custom site themes
2. Rebuild your NixOS configuration
3. Re-import the generated settings into Chrome
