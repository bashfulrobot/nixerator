# Nixerator

Personal NixOS / home-manager flake covering Dustin's hosts (`donkeykong`, `qbert`, `srv`). Module-based config, justfile-driven rebuilds, secrets via git-crypt, claude-code stack auto-imported.

See `~/.claude/CLAUDE.md` for the global *thin-CLAUDE.md protocol* and *Where curated knowledge goes* rubric. Project topic files live in `.claude/docs/`.

## Topics

- When making code changes — builds, rebuilds, lint, format, upgrades, git discipline, secrets — read `.claude/docs/conventions.md`.
- When adding or modifying a browser-wrapped web app under `modules/apps/webapps/`, read `.claude/docs/webapps.md` — `wmClass` must be verified with `lswt` after rebuild.
- When you need to look up docs for a Nix tool, library, or flake input, read `.claude/docs/sources.md` (context7 / gitmcp lookup table).
- When you need a local CLI tool (`amber`, `cpx`, `meetsum`, `gsd`, `nix-init`), read `.claude/docs/tools.md`.
- When the user asks about cross-device session pickup, the `work` fish function, the `claudeWorkHost` archetype, or how to attach to a session from the iPhone, read `.claude/docs/cross-device-workflow.md`.

## Reference docs

For deep-dive topics — directory structure, hosts, adding hosts, modules, packages, secrets, SSH, GPU, hyprland, VM dev, bootstrap — browse `extras/docs/` (one `.md` per topic). Start with `extras/docs/architecture.md` for the layout map.
