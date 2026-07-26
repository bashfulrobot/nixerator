---
name: send-to-dustin
description: >-
  Get text onto Dustin's clipboard or a file onto his phone, deriving the live
  Wayland socket first so it also works from background and headless sessions.
when_to_use: >-
  Use when Dustin says copy this to my clipboard, add it to my clipboard, put
  that on my clipboard, send this to my phone, send me the file, or send that
  over to my phone. Read BEFORE running `wl-copy` or `tailscale file cp`:
  WAYLAND_DISPLAY must be derived from the live socket under /run/user and never
  hardcoded as wayland-1, and a headless host has no clipboard at all.
effort: low
allowed-tools: ["Bash", "Read"]
---

# File Sharing

When asked to send a file to my phone, use:

```
sudo tailscale file cp /PATH/TO/FILE.EXT maximus:
```

# Clipboard

When asked to copy text to my clipboard ("copy to my clipboard", "add it to my clipboard"), pipe it to `wl-copy`. Background and headless sessions don't export `WAYLAND_DISPLAY`, so derive the live Wayland socket first — its number varies by host and reboot, so never hardcode `wayland-1`:

```
export WAYLAND_DISPLAY=$(basename "$(ls /run/user/$(id -u)/wayland-* 2>/dev/null | grep -v '\.lock$' | head -1)")
printf '%s' "TEXT" | wl-copy
```

If `WAYLAND_DISPLAY` comes back empty, the host is headless (e.g. `srv`) with no Wayland clipboard — tell me instead of silently succeeding.

## Related

For a visual artifact Dustin should see rather than store — a chart, a diagram,
a rendered page — rasterize it to PNG and hand it over with `SendUserFile`
rather than leaving it as a live preview. The `tailscale file cp` route above is
for files he wants to keep on the phone.
