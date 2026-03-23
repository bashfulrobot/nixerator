# Declarative Claude Code Config Management

## Problem

Claude Code config files (`settings.json`, `CLAUDE.md`, agents, skills) are
currently symlinked to the Nix store by Home Manager. This makes them read-only,
so Claude Code's own management tools (`/plugin install`, `/skills`, settings
changes) cannot write to them.

## Current State

All paths under `~/.claude/` that Home Manager manages are read-only symlinks:

```
~/.claude/settings.json     -> /nix/store/...-home-manager-files/.claude/settings.json
~/.claude/CLAUDE.md         -> /nix/store/...-home-manager-files/.claude/CLAUDE.md
~/.claude/agents/*.md       -> /nix/store/...-home-manager-files/.claude/agents/*.md
~/.claude/skills/*/SKILL.md -> /nix/store/...-home-manager-files/.claude/skills/*/SKILL.md
```

Non-Nix tools (GSD, claude-plugins) write real files alongside the symlinks,
which works for agents/ and skills/ (writable directories) but not for
settings.json (single symlinked file).

## Proposed Solution: Copy + Capture

Two-part workflow:

### Part 1: Nix copies files instead of symlinking

Stop using `programs.claude-code.settings`, `programs.claude-code.skills`, etc.
Instead, store the canonical config files directly in the nixerator repo and use
a Home Manager activation script to **copy** them into place.

```
modules/apps/cli/claude-code/
  config/                      # <-- canonical source, checked into git
    settings.json
    CLAUDE.md
    agents/
      nix.md
      go.md
      ...
    skills/
      commit/SKILL.md
      humanizer/SKILL.md
      ...
    output-styles/
      compact.md
```

Activation script (simplified):

```nix
home.activation.claudeConfig = lib.hm.dag.entryAfter ["writeBoundary"] ''
  src="${./config}"
  dest="$HOME/.claude"

  # Copy settings.json (always overwrite with Nix version)
  $DRY_RUN_CMD cp --no-preserve=mode "$src/settings.json" "$dest/settings.json"

  # Copy CLAUDE.md
  $DRY_RUN_CMD cp --no-preserve=mode "$src/CLAUDE.md" "$dest/CLAUDE.md"

  # Sync agents (preserve non-Nix agents like GSD)
  for f in "$src"/agents/*.md; do
    $DRY_RUN_CMD cp --no-preserve=mode "$f" "$dest/agents/$(basename "$f")"
  done

  # Sync skills (preserve non-Nix skills)
  for d in "$src"/skills/*/; do
    name=$(basename "$d")
    $DRY_RUN_CMD mkdir -p "$dest/skills/$name"
    $DRY_RUN_CMD cp --no-preserve=mode -r "$d"* "$dest/skills/$name/"
  done

  # Sync output styles
  $DRY_RUN_CMD mkdir -p "$dest/output-styles"
  for f in "$src"/output-styles/*; do
    $DRY_RUN_CMD cp --no-preserve=mode "$f" "$dest/output-styles/$(basename "$f")"
  done
'';
```

This means:

- Files are real, writable copies (not symlinks)
- Claude Code can modify them freely between rebuilds
- Every `nixos-rebuild switch` resets to the canonical Nix version
- Non-Nix files (GSD agents, externally installed skills) are preserved

### Part 2: Capture script (shell alias)

A simple command that copies the live Claude config back into the repo so changes
made via `/plugin`, `/skills`, or manual editing are captured for the next build.

```bash
claude-capture() {
  local repo="$HOME/dev/nix/nixerator/modules/apps/cli/claude-code/config"

  # Settings
  cp ~/.claude/settings.json "$repo/settings.json"

  # CLAUDE.md
  cp ~/.claude/CLAUDE.md "$repo/CLAUDE.md"

  # Agents (only copy non-GSD agents to avoid bloat)
  for f in ~/.claude/agents/*.md; do
    name=$(basename "$f")
    [[ "$name" == gsd-* ]] && continue
    cp "$f" "$repo/agents/$name"
  done

  # Skills
  for d in ~/.claude/skills/*/; do
    name=$(basename "$d")
    # Skip symlinked skills from external tools (superpowers, etc.)
    [[ -L "$d" ]] && continue
    mkdir -p "$repo/skills/$name"
    cp -r "$d"* "$repo/skills/$name/"
  done

  # Output styles
  mkdir -p "$repo/output-styles"
  for f in ~/.claude/output-styles/*; do
    [ -f "$f" ] || continue
    cp "$f" "$repo/output-styles/$(basename "$f")"
  done

  echo "Captured Claude config to $repo"
  echo "Review changes with: cd $(dirname "$repo") && git diff"
}
```

### Workflow

1. **Day-to-day**: Use Claude Code normally. `/plugin install`, manual edits,
   etc. all work because files are writable copies.

2. **When you want to persist changes**: Run `claude-capture`. Review the diff.
   Commit to git.

3. **On rebuild**: Nix copies the canonical versions back, resetting any drift.
   Changes you didn't capture are intentionally lost (Nix is source of truth).

4. **New machine**: `nixos-rebuild switch` copies all config into place. Done.

## Migration Steps

1. Export current generated config files from the Nix store into `config/`
2. Refactor `default.nix` to drop `programs.claude-code.settings/skills/agents/memory`
   and use the activation script instead
3. Keep `programs.claude-code.enable` and `programs.claude-code.package` (just the
   package installation)
4. Add `claude-capture` as a fish function
5. Test rebuild, verify files are writable copies
6. Test `/plugin install` works

## What stays in Nix vs. what moves to config/

| Currently in Nix                    | New location              |
| ----------------------------------- | ------------------------- |
| `programs.claude-code.settings`     | `config/settings.json`    |
| `programs.claude-code.memory.text`  | `config/CLAUDE.md`        |
| `programs.claude-code.agents`       | `config/agents/*.md`      |
| `programs.claude-code.skills`       | `config/skills/*/`        |
| `programs.claude-code.outputStyles` | `config/output-styles/`   |
| `programs.claude-code.mcpServers`   | stays empty / not needed  |
| `programs.claude-code.package`      | stays in Nix              |
| `programs.claude-code.enable`       | stays in Nix              |
| hooks (cfg/hooks-\*.nix)            | embedded in settings.json |
| permissions (cfg/permissions.nix)   | embedded in settings.json |
| statusLine script                   | stays in Nix (binary ref) |

## Open Questions

- Should `claude-capture` be a fish function or a standalone script in PATH?
- Should we auto-format settings.json with jq on capture for clean diffs?
- Should the activation script do a jq merge (preserve local additions) or full
  overwrite (strict reproducibility)? Recommend: full overwrite for simplicity.
- The statusLine command references a Nix store path. This still needs to be
  injected somehow (either template substitution or a wrapper script in PATH).
