# Nixerator

Personal NixOS / home-manager flake covering Dustin's hosts (`donkeykong`, `qbert`, `srv`). Module-based config, justfile-driven rebuilds, secrets via 1Password (`op inject`; git-crypt retired), claude-code stack auto-imported.

See `~/.claude/CLAUDE.md` for the global *thin-CLAUDE.md protocol* and *Where curated knowledge goes* rubric. Project topic files live in `.claude/docs/`.

## Topics

- When making code changes — builds, rebuilds, lint, format, upgrades, git discipline, secrets — read `.claude/docs/conventions.md`.
- When adding or modifying a browser-wrapped web app under `modules/apps/webapps/`, read `.claude/docs/webapps.md` — `wmClass` must be verified with `lswt` after rebuild.
- When you need to look up docs for a Nix tool, library, or flake input, read `.claude/docs/sources.md` (context7 / gitmcp lookup table).
- When you need a local CLI tool (`amber`, `cpx`, `meetsum`, `gsd`, `nix-init`), read `.claude/docs/tools.md`.
- When the user asks about cross-device session pickup, the `work` fish function, the `claudeWorkHost` archetype, or how to attach to a session from the iPhone, read `.claude/docs/cross-device-workflow.md`.
- **Secrets (hard rule):** NEVER read rendered secret values — not from `~/.config/nixos-secrets/secrets.json` and not from 1Password (`op read`/`op item get --reveal`), not even a prefix or length. Item titles, field labels, `op://` paths, and placeholders are fine. For the full 1Password flow — adding, rotating, per-host setup, the vault item table — read `extras/docs/secrets.md`.
- When a skill repeatedly resolves names→IDs or re-queries an external API for the same data, read `.claude/docs/skill-cache.md` for the warm-cache convention and the `skill-cache` CLI.
- When capturing DankMaterialShell (DMS) GUI settings back into Nix, or touching the dank capture/seed flow (`dank-capture`/`dank-diff`/`dank-discard`, `just capture`, `dank-profiles/`), read `.claude/docs/dank-capture.md`.
- When working with Claude Code plugins (the declarative marketplace/enabled surface in `cfg/plugin-config.nix`, `installed_plugins.json` capture behavior, or Kong Konnect skills showing installed but missing), read `.claude/docs/claude-plugins.md`.

## Reference docs

For a one-scroll visual overview — file map, module anatomy, the rebuild pipeline, the three hosts, secrets flow — open `extras/docs/index.html` (`just docs`). When building or editing that page, read `extras/docs/CLAUDE.md`.

For deep-dive topics — directory structure, hosts, adding hosts, modules, packages, secrets, SSH, GPU, hyprland, VM dev, bootstrap — browse `extras/docs/` (one `.md` per topic). Start with `extras/docs/architecture.md` for the layout map.
