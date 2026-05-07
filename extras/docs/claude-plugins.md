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

## Capturing Into NixOS Config

CLI commands are useful for discovery and initial install, but the goal is to
manage plugins/skills declaratively in nixerator so they survive rebuilds and
stay consistent across hosts.

After installing via CLI, capture what you want to keep:

1. **Skills** -- author or install in `~/.claude/skills/<name>/` and run
   `claude-capture` (or just `just qr`, which calls it as a pre-rebuild
   step). The capture function mirrors each runtime skill into
   `modules/apps/cli/claude-code/config/skills/<name>/`, and the activation
   script rsyncs that directory back into `~/.claude/skills/` on every
   rebuild. `config/skills/` is the single source of truth -- both the
   capture sink and the deploy source. Skills listed in
   `config/skills/.capture-ignore` are skipped.

2. **Plugins** -- inspect installed plugin content at
   `~/.claude/plugins/marketplaces/` or `~/.claude/plugins/cache/`.
   `claude-capture` also mirrors `installed_plugins.json`,
   `known_marketplaces.json`, and `blocklist.json` into
   `config/plugins/`, which the activation re-deploys on rebuild. Plugin
   content itself is fetched by Claude Code at runtime from the recorded
   marketplaces.

3. **Audit installed state** -- `claude plugin list` shows installed
   plugins; `ls ~/.claude/skills` shows active skills. Compare against
   `config/skills/` and `config/plugins/installed_plugins.json` to spot
   drift between runtime and committed state.

The pattern: discover or author at runtime, capture mirrors to git,
activation re-deploys on rebuild.
