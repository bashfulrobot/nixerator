# Skill defaults and skill-pick

Why skills default off, how the always-on baseline is chosen, and how
`skill-pick` turns individual ones on per project.

## The model

Skills used to have no gate at all: everything in `config/skills/` shipped
to every project, unconditionally -- unlike MCP servers, which already went
through `mcp-pick` (opt-in per project, nothing active by default). This
flipped skills to match that model, inverted:

- **MCP servers**: off everywhere by default, `mcp-pick` opts one in per
  project.
- **Skills**: off everywhere by default *except a short always-on baseline*,
  `skill-pick` opts anything else in per project.

The baseline exists because MCP servers have no equivalent to a global
CLAUDE.md hard-rule pointing at one by name, and no skill is invoked on
nearly every turn regardless of project the way `humanizer` or `commit` are.
A pure opt-in-only model would have silently broken the humanizer rule in
`~/.claude/CLAUDE.md` on every fresh project until someone remembered to run
`skill-pick` there first.

## Where each piece lives

- `cfg/skill-defaults.nix` -- the always-on baseline list (`alwaysOn`) and
  `mkOverlay`, which turns "every installed skill minus the baseline" into
  `{ skillOverrides = { name: "off", ... }; }`. Computed from a
  `builtins.readDir` of `config/skills/` plus the vendored (symlinked)
  skill names -- add a skill directory and it's off by default with zero
  extra wiring; add it to `alwaysOn` if it should ship on everywhere instead.
- `cfg/activation.nix` -- force-merges that overlay into
  `~/.claude/settings.json`'s `skillOverrides` key at user scope, every
  activation, same pattern as the plugin overlay (`cfg/plugin-config.nix`).
- `cfg/fish.nix` -- strips `skillOverrides` from what capture writes back to
  the repo, so a runtime edit can't drift the Nix-owned default.
- `cfg/scripts/skill-pick.bash` -- the picker, shipped as `skill-pick` on
  PATH (see `default.nix`). Per-project, writes into
  `.claude/settings.local.json` (gitignored).

## The baseline, and why each entry is there

Named directly in `~/.claude/CLAUDE.md`'s trigger-scoped rules -- removing
one would leave that rule pointing at nothing:

`bug-fix-workflow`, `code-style`, `merge-conflicts`, `git-cleanup`,
`rtk-output-compression`, `send-to-dustin`, `kong-docs-lookup`,
`curated-knowledge`

Confirmed heavy, cross-project usage by a claude-code doctor scan
(2026-07-30, 50 sessions):

`text-polish`, `humanizer`, `commit`, `github-issue`, `review-dev`,
`review-security`, `writing-style`, `auto`, `log-github-issue`, `sfdc`,
`kong-technical-csm`, `todoist-cli`, `gws-cli`, `slack-post`

`github-issue` is listed for documentation but has no actual effect in
`skill-defaults.nix`: it ships from `apps/cli/worktree-flow`, not
`config/skills`, so it never appears in the file's name list. It stays on by
Claude Code's own absent-key-means-on default anyway, which is what the
baseline wants -- harmless, just don't go looking for its override entry.

Re-adding a plugin/skill removed as unused should come with usage data
(same bar `modules/suites/ai/default.nix` already applies to plugins);
adding something new to the baseline should meet the same two-reason test
above, not "seemed useful."

## How `skill-pick` resolves precedence

The settings cascade resolves `skillOverrides` **per skill name**, not as a
whole-object replace: a project's `.claude/settings.local.json` value for a
given skill falls back to the user-scope value only when the project doesn't
mention that skill at all. Confirmed by reading the shipped CLI's actual
merge logic (`strings` on `.claude-wrapped`, not assumed):

```
skillOverrides?.[e] ?? Pr("userSettings")?.skillOverrides?.[e]
```

So an explicit `"on"` in the project file beats an `"off"` at user scope.
`skill-pick` uses this: it reads the Nix default from
`~/.claude/settings.json`, reads any existing project override, and on save
writes **only the skills whose pick differs from the Nix default** --
matching the default needs no entry at all, which is why most projects
converge to a handful of lines in `settings.local.json` instead of restating
every skill's state.

Accepted `skillOverrides` values, per the same source: `"off"` (hidden
everywhere), `"user-invocable-only"` (hidden from the model, still runnable
via `/name`), and no key at all, which means on. `skill-pick` only ever
writes `"on"` or `"off"`.

## Adding a new skill

Drop it in `config/skills/<name>/` as usual. It's off by default in every
project automatically -- nothing else to wire. If it should ship on
everywhere, add its name to `alwaysOn` in `cfg/skill-defaults.nix` with a
one-line reason, matching the bar above.
