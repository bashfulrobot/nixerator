# Vendored skills

Skills the claude-code module pulls from upstream repos through flake inputs
rather than checking into `config/skills/`, how they are pinned and deployed,
and the per-skill quirks worth knowing before touching one.

## The pattern

Eight skills from three flake inputs use it today (a former `humanizer`,
retired 2026-09-08, and a former `walkr-author` / `walkr-tutorial-author`,
retired 2026-09-09, are covered below instead):

| Skill | Flake input | Upstream | Path consumed |
|---|---|---|---|
| `intent-layer` | `crafter-station-skills` | `crafter-station/skills` | `context-engineering/intent-layer` |
| `awwwards-hero`, `awwwards-motion`, `awwwards-sections`, `brandkit-gen`, `imagegen-frontend`, `pixel-perfect`, `visual-redesign` | `vibecurb-skills` | `Yu-369/VibeCurb` | `skills/<name>` (seven directories) |

The `walkr` flake input still exists and is still consumed -- just not for
these two skills anymore. It also builds the `walkr` binary
(`modules/apps/cli/walkr`), which is unrelated to and unaffected by the
skill retirement below.

The seven VibeCurb skills share one input the same way, but unlike the other
vendored skills (each wired with its own explicit `rm -rf` + `ln -snf`
pair), `cfg/activation.nix` symlinks them with a `for skill in
${vibecurbSkillNames}` loop over the shared name list defined once in
`default.nix` -- past the project's three-occurrence DRY threshold for seven
near-identical lines. `default.nix`'s `vibecurbSkillNames` list is the single
source of truth: it feeds both the activation loop and the skill-overlay
`vendoredNames` (see `cfg/skill-defaults.nix`), so adding or removing a
VibeCurb skill only means editing that one list. `default.nix` also asserts,
at eval time, that every name in the list is path-safe and resolves against
the pinned rev, and that no vendored name collides with a `config/skills/`
directory -- see the assertions block right after the `CLAUDE.md` length
check.

All eight land as **symlinks** into the Nix store, created in
`cfg/activation.nix` right after the `config/skills/` rsync loop:

```
ln -snf "${intentLayerSkillSrc}" "$claude_home/skills/intent-layer"
```

The symlink is the whole point, not an implementation detail. Repo-owned skills
are rsynced with `--chmod=u+w` because Claude Code edits them at runtime and
`claude-capture` syncs those edits back. A vendored skill has no business being
edited locally — upstream owns it — so it stays read-only, and `capture-sync.py`
refuses to read through a symlink, which means the capture flow skips it for
free. No exclude list to maintain.

Bump `crafter-station-skills` with `nix flake update <input>` (or let `just
upgrade` sweep it). `flake.lock` records the rev, so it's pinned the same way
every other input is. `walkr` is still bumped this way too, but purely for
the binary now, not for anything in this list. `humanizer-skill` still exists
as a flake input (nothing consumes it anymore, see below) but is not part of
what `just upgrade` needs to keep current for this list's sake.

`vibecurb-skills` is different: its `url` in `flake.nix` embeds an explicit
rev (`github:Yu-369/VibeCurb/<rev>`), not a bare branch-tracking URL, because
this repo's `update-flake-lock` GitHub Action runs `nix flake update` on a
daily cron and pushes straight to `main` with no review -- see the comment on
the input in `flake.nix` for the full reasoning. A bare `nix flake update
vibecurb-skills` is therefore a no-op. Bump it by editing the rev in the URL
by hand, then `nix flake lock`, the same way `import-tree`'s tag pin is
bumped by editing the tag.

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
   `rm -rf` + `ln -snf` pair in `cfg/activation.nix`. If the input ships three
   or more skill directories worth taking (VibeCurb's seven, say), pass a Nix
   list of names instead and loop over it in the shell script — see the
   VibeCurb section below and `vibecurbSkillNames` in `default.nix`. Either
   way, guard the delete: check `[ -e "$target" ] && [ ! -L "$target" ]`
   before the `rm -rf` and warn instead of deleting, so a same-named skill a
   user or agent created at runtime doesn't vanish silently.
4. If the input's `url` has no explicit rev (a bare `github:org/repo`),
   decide whether it should be pinned the way `vibecurb-skills` is. The
   deciding question is whether this repo's `update-flake-lock` Action sweeps
   this input on its daily unattended cron: if so, and the vendored content
   is agent instruction text rather than compiled code, an unpinned URL lets
   a hostile upstream push reach `main` with no review inside 24 hours. Pin
   to an explicit rev in the URL if so, and add an eval-time `assertions`
   entry in `default.nix` confirming every consumed path still exists at
   that rev (`builtins.pathExists`) — see `vibecurbSkillNames`'s assertions
   for the pattern.
5. If the skill's scripts call a binary NixOS does not ship by default, add it
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

## humanizer, walkr-author, walkr-tutorial-author (retired as vendored skills)

Three skills `dk@claude-skills` now ships that used to be symlinked from a
flake input here. Both retirements follow the "if the repo has a real
`.claude-plugin/marketplace.json`, use `cfg/plugin-config.nix` instead"
guidance in "Adding another" above, applied in reverse: once the same
content is available from the marketplace, a second Nix-vendored copy is
redundant, not extra safety.

**humanizer** (retired 2026-09-08). MIT-equivalent single-`SKILL.md` repo,
no scripts, no dependencies. Load-bearing for the global writing rule in
`~/.claude/CLAUDE.md` — every piece of prose drafted for the user runs
through it. `text-polish` wraps it plus a concision pass, so anything
already polished must not be humanized again. No longer symlinked from the
`humanizer-skill` flake input: `dk@claude-skills` declares `humanizer` as an
installed-plugin dependency, sourced from the same upstream
(`blader/humanizer`). The `humanizer-skill` input and its
`humanizerSkillSrc` binding are still present (harmless, unused) rather than
removed outright.

**walkr-author / walkr-tutorial-author** (retired 2026-09-09, a day after
humanizer and for a less clear-cut reason worth spelling out). This
vendored copy was pinned to the exact same rev as the `walkr` binary
(`modules/apps/cli/walkr`, same `walkr` flake input), so the skill text and
the renderer's actual content-format contract could never drift apart —
unlike humanizer, retiring this one gives up a real correctness guarantee,
not just deduplicates identical content. Retired anyway, on the explicit
call that every machine should source these skills the same way: donkeykong
(this user's non-Nix machine) never had a vendored copy to begin with and
already runs on `dk@claude-skills` alone, with its `Gofile` installing
`walkr@latest` unpinned and a comment acknowledging the binary and the
skill copies "want bumping together" with nothing enforcing it. This
machine now accepts the same risk instead of being the one host that's
different. `walkrAuthorSkillSrc` / `walkrTutorialAuthorSkillSrc` and the
`walkr` flake input itself are left in place (the input still builds the
binary) rather than removed.

Both were **default-off** before retirement (`skill-pick` opt-in, not in
`skill-defaults.nix`'s `alwaysOn`) via `allVendoredSkillNames` membership.
Since a skill absent from `config/skills/` and `allVendoredSkillNames`
can't reach `skill-defaults.nix`'s `offNames` computation at all, it would
silently flip to Claude Code's absent-key-means-on default on retirement —
`mkOverlay`'s `extraOff` parameter (added for exactly this) is what keeps
`walkr-author` / `walkr-tutorial-author` default-off instead. `humanizer`
needed no such handling: it was already in `alwaysOn`.

## VibeCurb

MIT. Seven `SKILL.md`-only directories (no scripts, no dependencies) that
constrain a frontend-design agent to a strict audit-extract-build-verify
pipeline instead of generic AI defaults: `awwwards-hero` (hero sections),
`awwwards-motion` (scroll/kinetic animation), `awwwards-sections` (pricing
cards, bento grids, footers), `brandkit-gen` and `imagegen-frontend` (image
generation), `pixel-perfect` (screenshot-to-code replication), and
`visual-redesign` (restyle existing markup without touching logic).

Off by default like every other skill covered by `skill-defaults.md`; opt in
per project with `skill-pick` when working on a frontend/webapp module. Not a
replacement for the `frontend-design` plugin (`installed_plugins.json`) —
that one is Anthropic's general-purpose design-quality skill, VibeCurb is a
narrower, stricter, multi-skill pipeline. The two can be enabled together;
`skill-pick` treats them as independent entries.

The default-off overlay is a visibility default, not a trust boundary: per
the settings-cascade precedence in `skill-defaults.md`, a project-scope
`skillOverrides` entry (including one checked into a cloned repo's own
`.claude/settings.json`, not just the gitignored `settings.local.json`
`skill-pick` writes) beats the user-scope `"off"` default. A repo the user
opens can turn any of these seven back on without `skill-pick` ever running.
The seven skill files are also present on disk regardless of the override —
the overlay only controls whether the model sees them, not whether they're
installed. What actually bounds the risk of a compromised skill is the rev
pin on `vibecurb-skills` (see `flake.nix`): content can't change under this
project without a reviewed commit, whether the skill happens to be on or off
in any given project.

**Review note (rev `1bd3b135d22c110a0d8d2ddf17b1fdd58dee1ff0`, reviewed
2026-08-05).** Confirmed via the upstream repo tree: all seven `skills/<name>`
directories contain only a `SKILL.md`, no scripts, no other file types.
Confirmed via the GitHub license API: MIT. Read `imagegen-frontend` and
`brandkit-gen` (the two image-generation skills) in full: neither references
an API key, a credential, a specific network endpoint, or any outbound call —
they produce structured text prompts for whatever image-generation capability
the calling agent already has, they don't reach out themselves. Re-verify
this note before bumping the pinned rev.
