# Nixerator

Personal NixOS / home-manager flake covering Dustin's hosts (`qbert`, `srv`). Module-based config, justfile-driven rebuilds, secrets edited in 1Password (the source), snapshotted into the secauto gopass store for automation (`op inject` or `render-secrets --from gopass`; git-crypt retired), claude-code stack auto-imported.

Project topic files live in `.claude/docs/`.

`claude-skills` is a flake input here, pinned in `flake.lock`, so it supplies
`~/.claude/CLAUDE.md`, the status line and the plugin set. A merged
`claude-skills` change reaches `qbert` and `srv` only after `just update
claude-skills` plus a rebuild on each host.

## Assistant output

How Claude talks to Dustin on screen comes from the `dustin` output style,
which the `dk` plugin in `claude-skills` ships globally. `/dk:text-polish`
is the separate pass for prose sent elsewhere (Slack, email, docs).

## Topics

- When making code changes — builds, rebuilds, lint, format, upgrades, git discipline, secrets — read `.claude/docs/conventions.md`.
- When adding or modifying a browser-wrapped web app under `modules/apps/webapps/`, read `.claude/docs/webapps.md` — `wmClass` must be verified with `lswt` after rebuild.
- When you need to look up docs for a Nix tool, library, or flake input, read `.claude/docs/sources.md` (gitmcp lookup table).
- When you need a local CLI tool (`amber`, `cpx`, `meetsum`, `nix-init`), read `.claude/docs/tools.md`.
- When the user asks about cross-device session pickup, the `work` fish function, the `claudeWorkHost` archetype, or how to attach to a session from the iPhone, read `.claude/docs/cross-device-workflow.md`.
- **Secrets (hard rule):** NEVER read rendered secret values — not from `~/.config/nixos-secrets/secrets.json` and not from 1Password (`op read`/`op item get --reveal`), not even a prefix or length. Item titles, field labels, `op://` paths, and placeholders are fine. Secret edits are made by Dustin, or by the `opencode` CLI with a local model when he approves; a value never comes back to Claude. For the full 1Password flow — adding, rotating, per-host setup, the vault item table — read `extras/docs/secrets.md`.
- When a skill repeatedly resolves names→IDs or re-queries an external API for the same data, read `.claude/docs/skill-cache.md` for the warm-cache convention and the `skill-cache` CLI.
- When capturing DankMaterialShell (DMS) GUI settings back into Nix, or touching the dank capture/seed flow (`dank-capture`/`dank-diff`/`dank-discard`, `just capture`, `dank-profiles/`), read `.claude/docs/dank-capture.md`.
- When touching ncspot (`apps.cli.spotify`, the `ncspotPin` override, the `bashfulrobot/ncspot` fork, Spotify client ID rows in `gopass-map.tsv`, or Spotify 429 rate limits), read `.claude/docs/ncspot-pin.md`.
- When working with Claude Code plugins (the declarative marketplace/enabled surface in `cfg/plugin-config.nix`, `installed_plugins.json` capture behavior, or Kong Konnect skills showing installed but missing), read `.claude/docs/claude-plugins.md`.
- When touching `apps.cli.claude-code.stackApply`, the `claude-skills` flake input, `modules/apps/cli/claude-code/cfg/scripts/stack-apply.sh`, or deciding whether a `~/.claude` file is still nixerator's to own, read `.claude/docs/claude-stack-apply.md` — it holds the per-key ownership table, the per-host switch-on and rollback, and the phase-8 delete list.
- When touching `systemd.user` timers, `users.users.<name>.linger`, or a unit that assumes a graphical session, read `.claude/docs/user-lingering.md` — `Linger=yes` on a running host is not evidence the declaration exists.
- When adding a skill vendored from a flake input, or asking why a `~/.claude/skills` entry dangles, read `.claude/docs/vendored-skills.md`. No skill is vendored any more: `humanizer`, `walkr-author`, `walkr-tutorial-author`, `intent-layer` and the seven VibeCurb design skills were all retired, and that file holds the record, the add-one-back procedure and the by-hand cleanup each retirement leaves on qbert.
- When touching `server.nanoclaw` on srv (NanoClaw + OneCLI vault, its Slack channel, its 1Password-backed secrets, the setup-token re-auth flow, its backups), read `extras/docs/nanoclaw/README.md`.
- When touching the notes system (`apps.cli.notes`, `~/Notes`, zk, markless, Weave, the `notes*` commands, the Syncthing `notes` folder), read `extras/docs/notes.md`.
- When adding a skill, changing the always-on baseline, or debugging why a skill is missing/present in a project, read `.claude/docs/skill-defaults.md` for the default-off model and `skill-pick`.

## Reference docs

For a one-scroll visual overview — file map, module anatomy, the rebuild pipeline, the two hosts, secrets flow — open `extras/docs/index.html` (`just docs`). When building or editing that page, read `extras/docs/CLAUDE.md`.

For deep-dive topics — directory structure, hosts, adding hosts, modules, packages, secrets, SSH, GPU, hyprland, VM dev, bootstrap — browse `extras/docs/` (one `.md` per topic). Start with `extras/docs/architecture.md` for the layout map.

## TODO

Open work is tracked in `.claude/docs/todo.md`. Tick an item off there in the same commit that finishes it.

- When picking up open work or checking what is outstanding, read `.claude/docs/todo.md`.
