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

1. **Skills** -- copy into `modules/apps/cli/claude-code/skills/<name>/` and
   wire up via `skills.<name> = ./skills/<name>;` in the module. This is
   already how `commit` and `humanizer` work.

2. **Plugins** -- inspect installed plugin content at
   `~/.claude/plugins/marketplaces/` or `~/.claude/plugins/cache/`.
   Plugins are typically CLAUDE.md-style instruction files. Extract the
   useful bits and integrate into agents, skills, or memory as appropriate.

3. **Audit installed state** -- `claude-plugins list` and
   `npx skills-installer list` show what's currently active. Periodically
   review and pull anything worth keeping into Nix-managed files.

The pattern: discover with CLI, evaluate, then codify into the module.
