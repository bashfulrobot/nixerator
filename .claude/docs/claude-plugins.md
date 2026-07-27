# Claude Code plugins

How the claude-code module manages Claude Code's plugin surface, and how to fix
the one failure mode that has actually bitten us.

## Declarative surface (Nix-owned)

`modules/apps/cli/claude-code/cfg/plugin-config.nix` is the single source of
truth for `extraKnownMarketplaces` (marketplaces pinned to commit SHAs) and
`enabledPlugins`. Activation merges these two keys into the deployed
`~/.claude/settings.json`, and capture (`cfg/fish.nix`) strips them, so Nix owns
them and a bare runtime capture cannot unpin them. To add or bump a marketplace,
edit its entry in `plugin-config.nix` like a lock file.

`~/.claude/plugins/installed_plugins.json` is the opposite. It mirrors the live
runtime and is captured, not authored. Do not hand-author an entry for a plugin
that is not actually installed live: the next `just qu`/`qr` capture drops it,
because the live runtime has nothing backing it. This is exactly what happened to
the ai-marketplace seed added in #257, which the following capture ate.

## Runbook: Kong Konnect skills missing

**Symptom.** `kong-konnect@ai-marketplace` shows in `installed_plugins.json` as
installed, but its skills are unavailable and the cache directory
`~/.claude/plugins/cache/ai-marketplace/kong-konnect/<version>/` does not exist.

**Cause.** Claude Code's session-start declarative reconcile is not atomic. It
can write the install record and clone the marketplace, then skip copying the
plugin into the cache, leaving "installed" with zero skills. This is a Claude
Code bug, not a config error. The marketplace source SHA-pin is unrelated: the
cache path keys off the plugin's `version` (from its `plugin.json`), not the
source SHA. A working plugin like impeccable uses the same version-path scheme.

**Fix.**

```bash
claude plugin install kong-konnect@ai-marketplace --scope user
```

That forces the cache copy the reconcile skipped (it rebuilt all 20 skills).
Start a fresh Claude Code session to load them. There is no persistent
plugin-install log; use `claude --debug` if you need to watch the load.

## Pin-time trust review, and re-review on bump

Most marketplaces pinned in `plugin-config.nix` trace to a recognizable
source (Kong, heygen-com, pbakaus, JuliusBrussee, alexgreensh). A pin from a
single-author or low-star repo carries more risk per byte, especially if the
plugin ships a hook that can auto-approve a tool call (a `PreToolUse` hook
returning `permissionDecision: "allow"`) rather than only reading transcript
state. The comment at the pin should say what was actually checked, not just
assert "reviewed": which files, and for which properties (network calls,
filesystem writes, `child_process`/`eval`, the exact matching logic of any
auto-approval hook).

**semagraph** (issue #303) is the current example. Its `preapprove.js` grants
one narrow standing auto-approval: a Bash command whose entire first line
matches `node <this-plugin's-render.js> <<'DELIM'` with a single-quoted (so
non-expanding) heredoc delimiter, full-line anchored, no substring or prefix
match. `render.js` itself was read in full and has no `fs` writes, no
`require('child_process'|'net'|'http'|'https')`, and no `eval`; it parses JSON
and writes markdown. That is what makes the auto-approval acceptable here.

A SHA bump re-grants that trust wholesale. Re-run the same depth of review
(read every hook entrypoint and any auto-approval matcher in full, not just
a diff against the old SHA) before bumping a single-author marketplace,
and update the pin comment with what changed.
