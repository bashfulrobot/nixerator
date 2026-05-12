# Web apps

Workflow rules for adding or modifying browser-wrapped web apps under `modules/apps/webapps/` (built on `lib/mkWebApp.nix`).

## Always verify `wmClass` with `lswt`

The `wmClass` argument to `mkWebApp` must equal the Wayland `app-id` that Chromium actually reports for the running window. Pick one mechanically, rebuild, launch, then confirm:

```bash
just qr                                   # rebuild so the desktop file lands in the profile
gtk-launch <name>-webapp.desktop &        # launch the app (replace <name>)
lswt | grep chrome-                       # compare to the StartupWMClass in the .desktop
```

If `lswt`'s `app-id` does not match the `StartupWMClass` in `/etc/profiles/per-user/<user>/share/applications/<name>-webapp.desktop`, the module is wrong — update `wmClass`, rebuild, re-verify.

A mismatch silently breaks: Hyprland window rules, waybar `workspaceAppIcons` rewrites, and startup-notification dedup all key off the WM class.

## Why `--class` does not save you

`mkWebApp` passes `--class=<wmClass> --name=<wmClass>` to Chromium, but under Wayland Chromium **ignores those flags** and derives the app-id from the `--app=URL` instead:

- Pattern: `chrome-<host>__<path-with-/-as-_>-Default`
- Query string is dropped
- Trailing slash → empty path → double underscore

Examples (verified on qbert, 2026-05-12):

| URL | Actual `app-id` |
|---|---|
| `https://teams.cloud.microsoft/` | `chrome-teams.cloud.microsoft__-Default` |
| `https://app.zoom.us/wc/home` | `chrome-app.zoom.us__wc_home-Default` |
| `https://kong.lightning.force.com/lightning/r/Dashboard/01ZPJ000004TcSb2AK/view?queryScope=userFolders` | `chrome-kong.lightning.force.com__lightning_r_Dashboard_01ZPJ000004TcSb2AK_view-Default` |

So when the URL has a deep path, `wmClass` carries that path too. Changing the `url` in a webapp module usually means changing `wmClass` in the same edit.

## Optional fields

- `iconGlyph`: Nerd Font glyph used by `hyprflake.desktop.waybar.workspaceAppIcons.rewrites."class<${wmClass}>"`. Omit if you do not want a waybar icon.
- `mimeTypes` / `defaultFor`: only set if the app owns a URL scheme (e.g. `x-scheme-handler/msteams`, `x-scheme-handler/zoommtg`).
