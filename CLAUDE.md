# Nixerator

Multi-host NixOS flake with Home Manager, auto-imported modules, suites/archetypes, and git-crypt encrypted secrets.

## Project Rules

- Secrets live in `secrets/` (git-crypt encrypted). Never commit plaintext secrets.
- Avoid host-specific or machine-local paths; prefer `settings/globals.nix`.
- Formatting: `nix fmt`. Linting: `statix` + `deadnix`.
- All files must end with exactly one trailing newline.

@extras/docs/commands.md

## Project Map

- `flake.nix` and `settings/` — inputs, versions, and defaults.
- `hosts/` — per-host configs.
- `modules/` — archetypes, suites, apps, system, server, and dev modules.
- `packages/` — custom package overrides.
- `extras/docs/` — detailed documentation (open on demand, not duplicated here).

## Key Concepts

- **Archetypes** — high-level host profiles (`archetypes.workstation.enable = true`)
- **Suites** — feature bundles grouping related modules (`suites.dev.enable = true`)
- **Globals** — shared user/locale/preference config in `settings/globals.nix`

## Gotchas

- Module auto-import excludes `disabled/`, `build/`, and `cfg/` directories.
- `secrets/` is git-crypt encrypted; keep sensitive values there only.

## Docs (open only when needed)

- `extras/docs/architecture.md` — system architecture and file layout
- `extras/docs/commands.md` — full command reference (justfile, rebuilds, flake maintenance)
- `extras/docs/hosts.md` — host configurations and hardware notes
- `extras/docs/adding-hosts.md` — how to add a new host
- `extras/docs/modules.md` — module system, suites, archetypes, autoimport
- `extras/docs/adding-modules.md` — how to add new modules/apps
- `extras/docs/module-development.md` — module development details
- `extras/docs/secrets.md` — git-crypt setup and secrets management
- `extras/docs/external-deps.md` — primary upstream inputs and usage notes

## Maintenance

See `extras/docs/claude-md/CLAUDE.md` for editing guidance and conventions.
