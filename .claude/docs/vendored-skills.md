# Vendored skills

Skills the claude-code module pulled from upstream repos through flake inputs
rather than checking into `config/skills/`. Since 2026-10-26 there are none
left. This file is the retirement record, the procedure for adding one back,
and the by-hand cleanup each retirement leaves behind on qbert.

## Current state

| Skill | Was vendored from | Retired | Source now |
|---|---|---|---|
| `humanizer` | `humanizer-skill` | 2026-09-08 | `dk@claude-skills` plugin dependency, same upstream (`blader/humanizer`) |
| `walkr-author`, `walkr-tutorial-author` | `walkr` | 2026-09-09 | `dk@claude-skills` |
| `intent-layer` | `crafter-station-skills` | 2026-10-26 | nothing. The skill is gone from every source |
| `awwwards-hero`, `awwwards-motion`, `awwwards-sections`, `brandkit-gen`, `imagegen-frontend`, `pixel-perfect`, `visual-redesign` | `vibecurb-skills` | 2026-10-26 | the `vibecurb` plugin in claude-skills |

Two of those four inputs are gone from `flake.nix` and `flake.lock`:
`crafter-station-skills` and `vibecurb-skills` fed nothing else.
`humanizer-skill` stays, because `modules/apps/cli/antigravity/default.nix`
still reads its `SKILL.md` into `.gemini/config/skills/`. `walkr` stays,
because it builds the `walkr` binary (`modules/apps/cli/walkr`).

The 2026-10-26 pair came out of the audit in claude-skills
`docs/plans/personal-vs-upstream-assessment.md`, items A9 and A10. The
VibeCurb seven were byte-identical to the plugin's copies, with `cmp` silent
on all seven, and nothing referenced `intent-layer` by name: no CLAUDE.md
rule, no skill, no plugin, no script.

## Leftovers a rebuild will not remove

Activation only ever created these symlinks. Removing the loop stops them being
recreated, and leaves whatever is already in `~/.claude/skills` where it is. A
retired entry sits there as a symlink into a store path that garbage collection
will eventually take, so it reads as a dangling link.

qbert has every one of them. srv and the Mac have none. Check each path, then
remove it, one at a time, never with a wildcard:

```
ls -l ~/.claude/skills/humanizer
rm ~/.claude/skills/humanizer
ls -l ~/.claude/skills/walkr-author
rm ~/.claude/skills/walkr-author
ls -l ~/.claude/skills/walkr-tutorial-author
rm ~/.claude/skills/walkr-tutorial-author
ls -l ~/.claude/skills/intent-layer
rm ~/.claude/skills/intent-layer
ls -l ~/.claude/skills/awwwards-hero
rm ~/.claude/skills/awwwards-hero
ls -l ~/.claude/skills/awwwards-motion
rm ~/.claude/skills/awwwards-motion
ls -l ~/.claude/skills/awwwards-sections
rm ~/.claude/skills/awwwards-sections
ls -l ~/.claude/skills/brandkit-gen
rm ~/.claude/skills/brandkit-gen
ls -l ~/.claude/skills/imagegen-frontend
rm ~/.claude/skills/imagegen-frontend
ls -l ~/.claude/skills/pixel-perfect
rm ~/.claude/skills/pixel-perfect
ls -l ~/.claude/skills/visual-redesign
rm ~/.claude/skills/visual-redesign
```

Each is a symlink, so `rm` without `-r` is right and removes only the link.
Run `ls -l` first every time. If a path turns out to be a real directory, an
agent or the user wrote a skill under that name and `rm` would destroy work.

`worktree-flow` stopped writing three more on the same date. Those were real
directories holding home-manager-managed files, so the rebuild removes the
files and leaves the empty directories:

```
ls -l ~/.claude/skills/github-issue
rm -r ~/.claude/skills/github-issue
ls -l ~/.claude/skills/hack
rm -r ~/.claude/skills/hack
ls -l ~/.claude/skills/dependabot
rm -r ~/.claude/skills/dependabot
```

Run those three only after a rebuild with this change, and only once `ls -l`
shows nothing in them that home-manager did not put there. The dk plugin ships
all three skills under the same names, which is why the copies went: they had
drifted behind dk at 215 against 218, 297 against 300, and 779 against 799
lines.

## Default-off still holds

Every retired skill was default-off through `allVendoredSkillNames` membership
in `default.nix`, which feeds `cfg/skill-defaults.nix`'s `mkOverlay` as
`vendoredNames`. A skill absent from both `config/skills/` and that list never
reaches `offNames`, so retiring it would flip it to Claude Code's
absent-key-means-on default. `mkOverlay`'s `extraOff` parameter exists for that
case, and it now carries `walkr-author`, `walkr-tutorial-author` and the seven
VibeCurb names. `humanizer` needs no entry because it is in `alwaysOn`.
`intent-layer` needs none because there is no skill left to turn off.

`allVendoredSkillNames` is now `[ ]`. It stays, with the overlay call and the
collision assertion beside it, because it is the one place a new vendored skill
gets declared.

## Adding another

1. New input in `flake.nix` with `flake = false;`.
2. Bind it in `default.nix` next to `humanizerSkillSrc`, appending the
   subdirectory if the repo ships more than the one skill you want.
3. Pass it through the `activationConfig` argument set and add a `rm -rf` plus
   `ln -snf` pair in `cfg/activation.nix`. For three or more skill
   directories, pass a Nix list of names and loop over it in the shell script
   instead. Guard the delete either way: test `[ -e "$target" ] && [ ! -L
   "$target" ]` before the `rm -rf` and warn rather than delete, so a
   same-named skill a user or agent created at runtime does not vanish.
4. Add the name to `allVendoredSkillNames`, which is what keeps it default-off
   and what the collision assertion reads.
5. If the input's `url` has no explicit rev (a bare `github:org/repo`), decide
   whether to pin it. The deciding question is whether the vendored content is
   agent instruction text rather than compiled code: `just qu` sweeps every
   branch-tracking input, so an unpinned URL lets a hostile upstream push
   reach the next rebuild with nobody reading it. Pin to an explicit rev in
   the URL if so, and add an eval-time `assertions` entry in `default.nix`
   confirming every consumed path still exists at that rev
   (`builtins.pathExists`). The `vibecurb-skills` input carried both, and its
   history in this repo is the pattern to copy.
6. If the skill's scripts call a binary NixOS does not ship by default, add it
   to `environment.systemPackages` in `default.nix`.

Bump an input **before** a rebuild, never after. Activation resolves each store
path from `flake.lock`, so a lock bump that lands post-activation cannot reach
the generation that just switched. It is one full rebuild late by construction,
which is why `just update-skills` no longer runs `nix flake update`.

Prefer a plugin marketplace pin over this whole pattern whenever upstream ships
a real `.claude-plugin/marketplace.json`: `cfg/plugin-config.nix` pins the
marketplace SHA and lets Claude Code manage the install. Vendoring is for a
bare skill directory with no marketplace file. Both 2026-10-26 retirements are
that guidance read the other way round: once the marketplace carries the same
content, a second Nix-vendored copy only adds something that can drift.

## Why a symlink

Repo-owned skills are rsynced with `--chmod=u+w` because Claude Code edits them
at runtime and `claude-capture` syncs those edits back. A vendored skill has no
business being edited locally, since upstream owns it, so it stays read-only.
`capture-sync.py` refuses to read through a symlink, which means the capture
flow skips it with no exclude list to maintain.

## Notes kept from the retired entries

**intent-layer.** MIT. Set up hierarchical `AGENTS.md` context files across a
codebase: three read-only bash scripts plus three reference docs, writing
nothing but `AGENTS.md` files. Untouched upstream since 2026-02-05. Two
upstream defects, recorded in case it is ever reconsidered. Its
`estimate_tokens.sh` formats results with `echo "scale=1; $TOKENS/1000" | bc`
under `set -e`, so on a host without `bc` it prints its header and exits 127
for any directory over 1000 estimated tokens, which is every real one. That is
why `bc` is still in the module's `environment.systemPackages`. And
`analyze_structure.sh` tells you to run `estimate_tokens.py`, which does not
exist; the shipped script is `estimate_tokens.sh`.

**VibeCurb.** MIT. Seven `SKILL.md`-only directories, no scripts and no
dependencies, that constrain a frontend-design agent to an
audit-extract-build-verify pipeline: `awwwards-hero` for hero sections,
`awwwards-motion` for scroll and kinetic animation, `awwwards-sections` for
pricing cards, bento grids and footers, `brandkit-gen` and `imagegen-frontend`
for image generation, `pixel-perfect` for screenshot-to-code replication, and
`visual-redesign` for restyling existing markup without touching logic. The
`frontend-design` plugin is Anthropic's general-purpose design-quality skill
and covers different ground; the two can be on together.

The rev pin bounded the risk, and the `vibecurb` plugin pin in
`claude-stack.json` now does that job. The default-off overlay never was a
trust boundary: per the settings-cascade precedence in `skill-defaults.md`, a
project-scope `skillOverrides` entry beats the user-scope `"off"`, including
one checked into a cloned repo's own `.claude/settings.json` rather than the
gitignored `settings.local.json` that `skill-pick` writes. The files were also
on disk regardless of the override, since the overlay controls only whether the
model sees a skill.

**Review note, VibeCurb rev `1bd3b135d22c110a0d8d2ddf17b1fdd58dee1ff0`,
reviewed 2026-08-05.** All seven `skills/<name>` directories held only a
`SKILL.md`, confirmed against the upstream repo tree. MIT, confirmed against
the GitHub license API. `imagegen-frontend` and `brandkit-gen` were read in
full: neither referenced an API key, a credential, a network endpoint or any
outbound call. They produced structured text prompts for whatever
image-generation capability the calling agent already had. If the question ever
comes up again, re-run this review against the plugin's pinned SHA rather than
this rev.
