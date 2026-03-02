# Dark Reader Theme

Auto-generated Dark Reader settings using Stylix colors, placed at `~/.config/darkreader/settings.json` when `apps.gui.google-chrome` is enabled.

## Color Mapping

- **Dark Background**: base00 — **Dark Text**: base05
- **Light Background**: base07 — **Light Text**: base02
- Fallback values used if Stylix is not enabled

## Import into Chrome

1. Install Dark Reader extension
2. Settings > More > All Settings > Advanced > Import Settings
3. Select `~/.config/darkreader/settings.json`

Re-import after each rebuild to pick up color changes.

## Included Config

- System-based dark/light automation
- Custom site themes: `us2.app.sysdig.com` (mode 0, 80%), `calendar.google.com` (mode 1, 100%)
- PDF support, context menus, sync enabled

Edit `mkDarkReaderConfig` in `modules/apps/gui/google-chrome/default.nix` to customize.
