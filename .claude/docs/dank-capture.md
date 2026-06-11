# DMS (DankMaterialShell) settings capture

How GUI changes to DankMaterialShell are captured back into Nix and reapplied on rebuild. The *provider* (the capture model, options, and seed mechanics) lives in hyprflake — see its `docs/options.md` "DMS Settings Capture". This file covers the *consumer* (nixerator) side: the CLIs, the justfile integration, and the host policy.

## Model in one paragraph

With `hyprflake.desktop.dank.capture.enable = true` (set in the desktop suite), `~/.config/DankMaterialShell/settings.json` is **not** a read-only `/nix/store` symlink — it's a writable regular file seeded on activation from `merge(hyprflake defaults + stylix theme, captured profile)`. DMS writes GUI changes straight to it. `dank-capture` harvests the **full** live file (stylix theme keys stripped) into `dank-profiles/<group>.json`, which Nix reads back via `lib.importJSON` (so the JSON *is* declarative config — no `json2nix` needed). The theme always re-applies from stylix; captured settings win over hyprflake/consumer defaults. Group is `workstations` (shared across all workstation hosts), so the profile is last-write-wins.

## CLIs (on `$PATH`, provided by the hyprflake module)

- `dank-capture` — write live settings → `dank-profiles/<group>.json` (theme stripped), bless the seed marker.
- `dank-diff` — dry-run: print what `dank-capture` would write, no mutation.
- `dank-discard` — drop un-captured GUI edits, reset `settings.json` to the seeded config.
- `dank-settings-tool` — low-level JSON merge/diff/hash/without/equal (used by the others).

## justfile integration (host-agnostic)

Dank capture is folded into the capture flow alongside claude/agentos, but unlike them it runs on **every** host (any workstation may contribute), not just qbert:

- **`pre-rebuild`** runs `dank-capture` **before** the flake is evaluated, so the *same* rebuild's seed re-derives exactly what was captured (no clobber-guard "un-captured edits" warning). Ordering is the point — capturing after activation would lag a rebuild and warn.
- **`post-rebuild`** surfaces any `dank-profiles/` change with a `chore(dank): …` commit suggestion (captures are never auto-committed — only `flake.lock` is).
- **`just capture`** always applies `dank-capture` (on any host) before the qbert-gated claude/agentos block.

So the loop on any host is: tweak DMS in the GUI → `just qr`/`just qu` (or `just capture`) → review the `dank-profiles/` diff → commit only what you intend to share.

## Caveats

- **Shared full-file profile:** if two workstations ever hold genuinely divergent DMS state (e.g. monitor/display-specific keys DMS materialises differently per host), each host's rebuild captures its own state and you'll see flip-flop diffs. The manual-commit checkpoint is the safeguard — review before committing.
- **Whole-number floats:** the clobber-guard compares numerically, so DMS's `1` vs Nix's `1.0` (e.g. `dockTransparency`) is not treated as an edit.
- Wiring lives in `modules/suites/desktop/default.nix` (`hyprflake.desktop.dank.capture`) and the committed profile in `dank-profiles/`.
