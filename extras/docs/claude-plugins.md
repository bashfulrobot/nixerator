# Claude Plugins

Plugin and skills manager for Claude Code.
Installed via `pkgs.llm-agents.claude-plugins` in `modules/apps/cli/claude-code/`.

- Registry: https://claude-plugins.dev
- Source: https://github.com/Kamalnrf/claude-plugins

## Commands

### Plugins (`claude-plugins`)

Plugins install to `~/.claude/plugins/marketplaces/`.

- `claude-plugins install <identifier>` -- install a plugin from the registry
- `claude-plugins list` -- show installed plugins
- `claude-plugins enable <name>` -- re-enable a disabled plugin
- `claude-plugins disable <name>` -- disable without removing

Example:

```
claude-plugins install @anthropics/claude-plugins-official/code-review
```

### Skills (`skills-installer` via npx)

`skills-installer` is a separate npm package, not included in the Nix package.
Run via `npx` when needed for interactive skill discovery.

Skills install to `~/.claude/skills/` (global) or `./.claude/skills/` (local).

- `npx skills-installer search [query]` -- interactive terminal search/browse
- `npx skills-installer install <identifier>` -- install a skill
- `npx skills-installer install <identifier> --local` -- install to current project only
- `npx skills-installer list` -- show installed skills

Example:

```
npx skills-installer search frontend
npx skills-installer install @anthropics/claude-code/frontend-design
```

## Managing In NixOS Config

The goal is to manage plugins and skills in nixerator so they survive rebuilds
and stay consistent across hosts. The two surfaces are handled differently:

- **Skills** are *captured* from runtime (discover/author in `~/.claude`, then
  `claude-capture` mirrors them into git).
- **Plugins + marketplaces** are *authored directly in Nix* (`plugin-config.nix`,
  SHA-pinned) and merged into the deployed `settings.json` -- they are **not**
  captured. The `claude-plugins` / `claude plugin` CLIs above are for ad-hoc
  discovery and experimentation only; the durable, reproducible state lives in
  `plugin-config.nix`.

1. **Skills** -- author or install in `~/.claude/skills/<name>/` and run
   `claude-capture` (or just `just qr`, which calls it as a pre-rebuild
   step). The capture function mirrors each runtime skill into
   `modules/apps/cli/claude-code/config/skills/<name>/`, and the activation
   script rsyncs that directory back into `~/.claude/skills/` on every
   rebuild. `config/skills/` is the single source of truth -- both the
   capture sink and the deploy source. Skills listed in
   `config/skills/.capture-ignore` are skipped.

2. **Plugins + marketplaces (declarative, SHA-pinned)** -- which marketplaces
   are trusted and which plugins are enabled is **authored in Nix**, not
   captured. The single source of truth is
   `modules/apps/cli/claude-code/cfg/plugin-config.nix`: it defines
   `extraKnownMarketplaces` (the active third-party marketplaces, each pinned to
   a commit `sha`) and `enabledPlugins` (the full `<plugin>@<marketplace>` set).
   The activation script merges those two keys into the deployed
   `~/.claude/settings.json`, and `claude-capture` **strips** them from the
   captured repo `settings.json` so the runtime copy can't clobber the pinned
   Nix values. `claude-plugins-official` is the built-in Anthropic marketplace
   and is intentionally **not** declared. To bump a marketplace, change its
   `sha` in `plugin-config.nix` (like bumping `flake.lock`); to add/remove a
   plugin, edit `enabledPlugins`.

   Only two runtime files are still captured + re-deployed, because they have no
   `settings.json` equivalent: `installed_plugins.json` (the SHA-stamped install
   record, which seeds an already-cached host) and `blocklist.json` (managed
   plugin blocklist). `known_marketplaces.json` is **no longer** captured or
   deployed -- it is regenerated at session start from the declarative
   `extraKnownMarketplaces`. Plugin content itself is fetched by Claude Code at
   runtime from the pinned marketplace SHAs.

3. **Audit installed state** -- `claude plugin list` shows installed
   plugins; `ls ~/.claude/skills` shows active skills. Compare against
   `config/skills/` and `config/plugins/installed_plugins.json` to spot
   drift between runtime and committed state.

The pattern differs by surface: **skills** are discovered/authored at runtime
and captured to git; **plugins + marketplaces** are authored in Nix
(`plugin-config.nix`) and merged into `settings.json` at activation. Both
re-deploy on rebuild.
