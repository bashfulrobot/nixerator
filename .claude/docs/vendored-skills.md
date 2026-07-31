# Vendored skills

Skills the claude-code module pulls from upstream repos through flake inputs
rather than checking into `config/skills/`, how they are pinned and deployed,
and the per-skill quirks worth knowing before touching one.

## The pattern

Four skills from three flake inputs use it today:

| Skill | Flake input | Upstream | Path consumed |
|---|---|---|---|
| `humanizer` | `humanizer-skill` | `blader/humanizer` | whole repo |
| `intent-layer` | `crafter-station-skills` | `crafter-station/skills` | `context-engineering/intent-layer` |
| `walkr-author` | `walkr` | `bashfulrobot/walkr` | `skills/walkr-author` |
| `walkr-tutorial-author` | `walkr` | `bashfulrobot/walkr` | `skills/walkr-tutorial-author` |

The two walkr skills share the `walkr` input with the `walkr` binary
(`modules/apps/cli/walkr`), so the tool and the skills that author its content
are pinned to the same rev by construction.

All four land as **symlinks** into the Nix store, created in `cfg/activation.nix`
right after the `config/skills/` rsync loop:

```
ln -snf "${humanizerSkillSrc}" "$claude_home/skills/humanizer"
```

The symlink is the whole point, not an implementation detail. Repo-owned skills
are rsynced with `--chmod=u+w` because Claude Code edits them at runtime and
`claude-capture` syncs those edits back. A vendored skill has no business being
edited locally — upstream owns it — so it stays read-only, and `capture-sync.py`
refuses to read through a symlink, which means the capture flow skips it for
free. No exclude list to maintain.

Bump any of them with `nix flake update <input>` (or let `just upgrade` sweep
them). `flake.lock` records the rev, so these are pinned the same way every
other input is.

Bump them **before** a rebuild, never after. Activation resolves each store
path from `flake.lock`, so a lock bump that lands post-activation cannot reach
the generation that just switched — it is one full rebuild late by
construction. That is why `just update-skills` no longer runs
`nix flake update`; the recipe carries a comment saying so.

## Adding another

1. New input in `flake.nix` with `flake = false;`.
2. Bind it in `default.nix` next to `humanizerSkillSrc` — append the
   subdirectory if the repo ships more than the one skill you want.
3. Pass it through the `activationConfig` argument set and add the two-line
   `rm -rf` + `ln -snf` pair in `cfg/activation.nix`.
4. If the skill's scripts call a binary NixOS does not ship by default, add it
   to `environment.systemPackages` in `default.nix` — see `bc` below.

Prefer this over a plugin marketplace pin only when upstream ships a bare skill
directory. If the repo has a real `.claude-plugin/marketplace.json`, use
`cfg/plugin-config.nix` instead; that pins the marketplace SHA and lets Claude
Code manage the install.

## intent-layer

MIT. Sets up hierarchical `AGENTS.md` context files across a codebase. Three
read-only bash scripts (`detect_state.sh`, `analyze_structure.sh`,
`estimate_tokens.sh`) plus three reference docs; the scripts write nothing, and
the skill's only output is `AGENTS.md` files in whatever project it is pointed
at.

Upstream's `marketplace.json` sits at the repo root instead of under
`.claude-plugin/`, so `/plugin marketplace add crafter-station/skills` does not
find it. That is why this is a vendored skill and not a marketplace pin.

Two upstream defects to know about:

- **`estimate_tokens.sh` needs `bc`.** It formats results with
  `echo "scale=1; $TOKENS/1000" | bc` under `set -e`, so on a host without `bc`
  it prints its header and then exits 127 at line 60 — for any directory over
  1000 estimated tokens, which is every real one. Verified both ways against
  `modules/apps/cli/claude-code`: 127 and no total without `bc`, `~382.7k` and
  a recommendation with it. That is why `bc` is in the module's
  `environment.systemPackages`. If a future bump drops the `bc` call, that
  entry can go with it.
- **`analyze_structure.sh` tells you to run `estimate_tokens.py`.** No such
  file exists — the shipped script is `estimate_tokens.sh`, which the skill's
  own Resources section names correctly. Harmless, self-correcting, and not
  worth patching a store path over.

The skill has been untouched upstream since 2026-02-05, so do not expect a bump
to fix either.

## humanizer

MIT-equivalent single-`SKILL.md` repo, no scripts, no dependencies. Load-bearing
for the global writing rule in `~/.claude/CLAUDE.md` — every piece of prose
drafted for the user runs through it. `text-polish` wraps it plus a concision
pass, so anything already polished must not be humanized again.
