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
runtime and is captured, not authored. Hand-authoring an entry for a plugin that
is not installed live gets you nothing useful: it survives in the file but has no
runtime behind it. That is what happened to the ai-marketplace seed added in
#257 — it never did anything.

### The fixpoint: prune both sides or neither

`installed_plugins.json` and `blocklist.json` are the **only** capture surface in
this module with no three-way snapshot guard. `cfg/activation.nix` copies
repo → live unconditionally on every rebuild; `cfg/fish.nix` copies live → repo
unconditionally on every capture. Nothing compares against a snapshot to decide
who wins, so it is last-writer-wins in both directions, and the two writers run
back to back on a single `just qr`: activation re-seeds live from the repo
*before* post-rebuild capture reads live back.

The practical consequence: **editing only one side is always silently reverted by
the other.**

- Delete a stale key from the repo copy only → activation is a no-op for it,
  but the next capture reads the still-stale live copy and puts it back.
- Delete it from the live copy only → the next activation re-seeds it from the
  repo copy.

Do not assume a capture will "clean up" an entry the way it would for a
genuinely runtime-owned file. When a plugin is dropped from
`cfg/plugin-config.nix`, prune its key from **both** copies in the same change,
and delete its `~/.claude/plugins/cache/<marketplace>/<plugin>/` directory too.
This is why #328's plugin removals left stale state behind until the follow-up
audit — see the code comment in `cfg/fish.nix` at the capture block.

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

The claims above aren't independently checkable from inside this repo (the
vendored plugin source isn't committed here, only referenced by SHA), so a
future reader has to trust the prose. Below is the SHA256 of each reviewed
file's raw content (not the git blob hash) at `9e57466bfdd220de164c7e29f578c79f9b12b1b7`,
so a bump can diff the new content against what was actually read instead of
against what a comment claims:

```
hooks/preapprove.js  b1635822fde5e640b5b45ea09f625781299003bc50ebcf1b336fcd07c6306418
hooks/stop.js        31aa625f9102257e25a1dfb080f901674ad8468152dc4205104cd6d583bf7603
bin/render.js        a15c14dbcc2fd5d3ae7ac81ee3379035632be6d9bcd3c6f7dfef1aba7db770da
```

Reproduce with `gh api "repos/Or1onn/Semagraph/contents/<path>?ref=<sha>" | jq
-r '.content' | base64 -d | sha256sum`, no newline normalization applied. A
mismatch against these values on a re-fetch of the same SHA means the fetch
method differs (CRLF vs LF, a proxy rewriting content), not that the plugin
changed; re-derive with the exact command above before treating it as drift.

A SHA bump re-grants that trust wholesale. Re-run the same depth of review
(read every hook entrypoint and any auto-approval matcher in full, not just
a diff against the old SHA) before bumping a single-author marketplace,
and update the pin comment with what changed.
