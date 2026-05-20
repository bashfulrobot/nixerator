# Web apps

Workflow rules for adding or modifying browser-wrapped web apps under `modules/apps/webapps/` (built on `lib/mkWebApp.nix`).

## Process isolation: each PWA owns its Chrome profile

`mkWebApp` launches every PWA with `--user-data-dir=$HOME/.config/google-chrome-<name>`. This forces a separate Chrome process per PWA — without it, Chromium reuses the regular browser's Wayland connection and PWA app-ids leak onto the browser's windows (the workspace icon ends up wrong for the regular Chrome browser whenever any PWA is running).

Each PWA is a **fresh Chrome profile**: no extensions, no logins, on first launch. Use the Manage launcher (below) to set them up.

## Always verify `wmClass` with `lswt`

The `wmClass` argument to `mkWebApp` must equal the Wayland `app-id` that Chromium actually reports for the running window. Pick one mechanically, rebuild, launch, then confirm:

```bash
just qr                                   # rebuild so the desktop file lands in the profile
gtk-launch <name>-webapp.desktop &        # launch the app (replace <name>)
hyprctl clients -j | jq -r '.[].class'    # or `lswt | grep chrome-`
```

If the live `app-id` does not match the `StartupWMClass` in `/etc/profiles/per-user/<user>/share/applications/<name>-webapp.desktop`, the module is wrong — update `wmClass`, rebuild, re-verify.

A mismatch silently breaks: Hyprland window rules, waybar `workspaceAppIcons` rewrites, and startup-notification dedup all key off the WM class.

## Why `--class` does not save you

`mkWebApp` passes `--class=<wmClass> --name=<wmClass>` to Chromium, but under Wayland Chromium **ignores those flags** and derives the app-id from the `--app=URL` instead:

- Pattern: `chrome-<host-with-:-as-__><__><path-with-/-as-_>-Default`
- Query string is dropped
- Fragment (`#…`) is dropped
- Trailing slash → empty path → double underscore before `-Default`
- The `-Default` suffix is the **profile-directory name** inside `--user-data-dir`. Chrome auto-creates `Default/` in each per-PWA `--user-data-dir`, so the suffix is always `-Default` even though the user-data-dir basename differs.

Examples (verified on qbert, 2026-05-20):

| URL | Actual `app-id` |
|---|---|
| `https://teams.cloud.microsoft/` | `chrome-teams.cloud.microsoft__-Default` |
| `https://app.zoom.us/wc/home` | `chrome-app.zoom.us__wc_home-Default` |
| `https://claude.ai/new` | `chrome-claude.ai__new-Default` |
| `https://192.168.169.2:3131/` | `chrome-192.168.169.2__3131-Default` |
| `https://kong.lightning.force.com/lightning/r/Dashboard/01ZPJ000004TcSb2AK/view?queryScope=userFolders` | `chrome-kong.lightning.force.com__lightning_r_Dashboard_01ZPJ000004TcSb2AK_view-Default` |

When the URL has a deep path, `wmClass` carries that path too. Changing the `url` in a webapp module usually means changing `wmClass` in the same edit.

## Manage launcher

For every PWA, `mkWebApp` also emits a sibling `<name>-webapp-manage.desktop` titled `Manage <DisplayName>` (categorised as `Settings` so app launchers group them together). It opens the same `--user-data-dir` as a **normal browser window** — URL bar, extensions toolbar, and `chrome://extensions/` all available.

Use it to:

- Install per-PWA extensions (password manager, grammar tool, etc.) from the Chrome Web Store
- Sign into those extensions (1Password, etc.) — once per PWA profile
- Sign into the web service the first time
- Inspect cookies, clear site data, debug

The PWA window itself inherits everything because both desktop entries point at the same `--user-data-dir`.

## Optional fields

- `iconGlyph`: Nerd Font glyph used by `hyprflake.desktop.waybar.workspaceAppIcons.rewrites."class<${wmClass}>"`. Omit if you do not want a waybar icon.
- `mimeTypes` / `defaultFor`: only set if the app owns a URL scheme (e.g. `x-scheme-handler/msteams`, `x-scheme-handler/zoommtg`).
- `extraArgs`: appended to the PWA exec line. Use sparingly — most needs are already covered by the default flags.
