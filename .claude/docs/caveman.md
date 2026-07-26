# caveman

What the caveman plugin injects, which intensity this host runs, and how to
drop out of it per-repo, per-session, or entirely.

Upstream: [JuliusBrussee/caveman](https://github.com/JuliusBrussee/caveman).
MIT. Pinned at v1.9.1 (`0d95a81d35a9f2d123a5e9430d1cfc43d55f1bb0`), added
2026-07-25.

## What it does

Shortens Claude's *output* by injecting a ruleset that tells it to answer in
clipped, article-free prose — "smart caveman". It is pure prompt engineering:
no filtering of tool results, no compression of input. That makes it the
output-side counterpart to `token-optimizer`, which measures the context window
but does nothing about reply length.

Two hooks carry it:

| Hook | Script | Job |
|---|---|---|
| `SessionStart` | `caveman-activate.js` | Reads the active mode, writes `~/.claude/.caveman-active`, emits the ruleset as hidden session context |
| `UserPromptSubmit` | `caveman-mode-tracker.js` | Watches for mode switches and re-injects a reminder every turn while active |

Both invoke bare `node` from `${CLAUDE_PLUGIN_ROOT}`, which resolves fine — the
user profile carries node. Nothing here needs the FHS plumbing
`token-optimizer` does.

## Where it lives

| Concern | File |
|---|---|
| Marketplace SHA pin | `modules/apps/cli/claude-code/cfg/plugin-config.nix` |
| `defaultMode` config + `hasCaveman` gate | `modules/apps/cli/claude-code/default.nix` |
| Host enablement | `modules/suites/ai/default.nix` (workstations only) |

Everything is gated on `caveman@caveman` appearing in
`apps.cli.claude-code.plugins`; dropping the id also drops the config file.

## The configured mode

The module ships `~/.config/caveman/config.json` containing
`{"defaultMode":"full"}`. `full` is the middle intensity and matches upstream's
own default; it is pinned rather than left implicit so a change to that default
at some future SHA can't quietly move the host.

A read-only store symlink is safe for this file. caveman reads the user config
with a plain `readFileSync` + `JSON.parse` and no trust gate; its symlink
refusal applies to the flag file and to repo-local `.caveman.json`, not here.

Two consequences of running any mode other than `off`, both expected:

- **The ruleset is injected at every SessionStart**, so it competes with the
  `compact` output style and the humanizer / Canadian-English prose rules in
  `~/.claude/CLAUDE.md`. caveman's own Boundaries section exempts commits, PRs
  and security warnings, and its Auto-Clarity section exempts irreversible-action
  confirmations and multi-step sequences, which covers most of the overlap — but
  not free-form prose drafted for someone else to read. Drop out before drafting
  a Slack message or a customer email.
- **The brevity autodetect is live.** The tracker re-asserts the mode on
  **"be brief", "be terse", "less tokens", "fewer tokens", "shorter answers"**.
  That switch is session-wide and persistent, not a one-off, so an offhand "be
  brief" does more than shorten the next answer.

## Changing or dropping it

Three levers, in the plugin's own precedence order:

1. `CAVEMAN_DEFAULT_MODE=off` — env var, outranks everything, no rebuild. The
   fastest way to get a normal-prose session.
2. A repo-local `.caveman.json` or `.caveman/config.json` — per-project, found
   by walking up from cwd. The right lever for a docs- or prose-heavy repo.
3. Edit `cavemanConfigFile` in `default.nix` and rebuild — the permanent answer.

Mid-session, `/caveman off`, "stop caveman", or "normal mode" all deactivate;
`/caveman lite|full|ultra|wenyan-*` switches intensity, and `/caveman-commit`,
`/caveman-review`, `/caveman-compress` invoke their own one-shot skills and then
restore the prose mode that was displaced. Bare `/caveman` resolves to the
configured default, so it re-asserts `full`.

## Things left alone on purpose

- **The statusline.** `caveman-activate.js` only nudges about statusline setup
  when `settings.json` has no `statusLine` key. The module always sets one
  (`statusline.sh`), so the nudge never fires and nothing contends for the slot.
  Unlike `token-optimizer`, caveman's plugin path never writes `settings.json`
  itself — only its standalone `bin/install.js` does, and that installer is not
  used here.
- **Runtime state.** `.caveman-active`, `.caveman-active.prev`,
  `.caveman-mode-log.jsonl`, `.caveman-history.jsonl` and
  `.caveman-statusline-suffix` all live at the root of `~/.claude/`.
  `capture-sync.py` tracks `skills/`, `agents/`, `output-styles/` and
  `CLAUDE.md`, so none of them leak into the repo.
- **`/caveman-stats`.** The tracker intercepts this one and returns
  `{"decision":"block"}` with the stats as the reason, so the prompt never
  reaches the model. Expected behaviour, not a bug.

## Bumping

Same as any pinned marketplace — new HEAD into `cfg/plugin-config.nix`:

```bash
git -C ~/.claude/plugins/marketplaces/caveman rev-parse origin/main
```

Upstream is largely agent-maintained (a heartbeat branch and a dozen
`worktree-agent-*` branches), so prefer a release tag over raw `main`. After a
bump, re-check `src/hooks/caveman-config.js` for changes to `VALID_MODES` or
the config precedence order — if `full` ever stops being a valid mode string,
`getDefaultMode()` silently falls through to upstream's default instead of
erroring, and the pin in `default.nix` becomes a no-op.
