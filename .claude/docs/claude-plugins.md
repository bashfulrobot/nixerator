# Claude Code plugins

How the claude-code module manages Claude Code's plugin surface, and how to fix
the one failure mode that has actually bitten us.

## Declarative surface (manifest-owned, Nix-applied)

The plugin and marketplace set is no longer authored in this repo. It comes from
the claude-stack manifest in `bashfulrobot/claude-skills`
(`claude-stack/claude-stack.json`; schema in that repo's
`docs/ai/claude-stack.md` and `unified-stack.md`). Its resolver writes
`claude-stack/resolved/<host>.json`, and this repo carries a committed snapshot
of the NixOS hosts' files:

```
modules/apps/cli/claude-code/cfg/claude-stack/qbert.json
modules/apps/cli/claude-code/cfg/claude-stack/srv.json
```

`cfg/plugin-config.nix` reads the snapshot for `apps.cli.claude-code.stackHost`
(default: the hostname; donkeykong has no manifest entry and is set to `qbert`
in `hosts/donkeykong/modules.nix`) with `builtins.fromJSON` and builds two keys:

- `enabledPlugins`: state `enabled` -> `true`, `disabled` -> `false`, `absent`
  -> key omitted.
- `extraKnownMarketplaces`: the manifest's resolved non-builtin marketplaces,
  each pinned to its manifest sha. `claude-skills` is `selfPin` in the manifest
  (no sha), so its sha comes from the pin in `plugin-config.nix`.

Activation merges these two keys into the deployed `~/.claude/settings.json`,
and capture (`cfg/fish.nix`) strips them, so Nix owns them and a bare runtime
capture cannot unpin them. Per-host `plugins = [ ... ]` lists no longer exist:
`modules/suites/ai`, `hosts/srv/modules.nix` and the superpowers module carry
only pointer comments. The plugin-gated extra `hasHyperframes`
tests the snapshot's enabled ids. (token-optimizer and its `hasTokenOptimizer`
plumbing were removed everywhere; see below.) The manifest's `config` and
`secrets` per plugin are not applied by Nix yet (userConfig/secret wiring is a
later phase); only state and marketplaces are. Their `secrets` refs already
use the single `automation` 1Password vault (see below).

### Permissions: add-only union, runtime-owned

The snapshot's `permissions.allow` (manifest syntax is the normalised
`Bash(x *)`; the resolver already folds `Bash(x:*)` into it) is merged into
`~/.claude/settings.json` at activation as an ordered, add-only union
(`cfg/activation.nix`, fed by `permissionsAllow` in `plugin-config.nix`).
Existing rules keep their order and are never removed; declared rules not
already present are appended in manifest order. A live `Bash(x:*)` counts as
present for a declared `Bash(x *)`, so the legacy spelling is not duplicated.
`permissions.deny` is not touched.

This is unlike `enabledPlugins`: permissions stay runtime-owned. Capture
(`cfg/fish.nix`) strips only `permissions.ask`, so `permissions.allow`
round-trips into `config/settings.json`, appended rules included. The union is
idempotent, so capture -> activation -> capture is a fixpoint. Consequence:
removing a rule from the manifest does not revoke it on a host; delete it from
`config/settings.json` and the live file by hand. Both snapshots currently
declare an empty allow list, so the merge is a no-op until the manifest gains
rules. Not verified end to end (no nix on the authoring Mac); the jq filter was
tested standalone for ordering, `:*` normalisation and idempotence.

### Changing the set, and the pin/snapshot coupling

Add, drop or re-pin a plugin or marketplace in `claude-stack.json` in
claude-skills, run `just stack-resolve` there, merge, then here run
`just bump-claude-skills` (or `just upgrade`). The bump script resolves the new
claude-skills sha, fetches `claude-stack/resolved/{qbert,srv}.json` at THAT sha
with `gh api` (private repo, no flake input), validates them, and rewrites both
the pin and the snapshot files in one go, so pin and snapshot always come from
the same sha. `just commit-plugin-config` commits the pin and the snapshot
together. Pass a 40-hex sha instead of a branch to pin an exact commit.

Snapshot seeded from the unmerged claude-skills PR #54 (branch
`feat/claude-stack-phase1`). Once #54 merges, re-run
`just bump-claude-skills` so the pin and snapshot come from a main sha.

### Dropped plugins: why (moved from the old per-host lists)

The old workstation list's rationale, kept here so it survives the list's
removal. All were dropped on usage data (#294 token-surface audit over 90 days
of transcripts; claude-code doctor 2026-07-30), and re-adding any needs usage
data, not a hunch:

- learning-output-style: injects a system-prompt block that hands TODOs back
  to the user; inflates turn count.
- pr-review-toolkit, feature-dev: agent definitions (~1.8k tokens resident for
  the former), dispatched once or never; review-dev/review-security cover it.
- context7: duplicate mount; the user-scoped server in `cfg/mcp-servers.nix` is
  the single source.
- asana, atlassian, github: MCP servers sat unauthenticated, no real use
  (github work goes through `gh`).
- code-review, kotlin-lsp, rust-analyzer-lsp, kong-skills@kong-skills,
  kong-skill, commit@kong-skills, feature-request@kong-skills, impeccable,
  hyperframes, kong-konnect@ai-marketplace: zero usage over 50 sessions; several
  were shadowed by the personal review-dev, commit and feature-request skills.
- token-optimizer@alexgreensh-token-optimizer: removed everywhere (module
  option, `cfg/token-optimizer.nix`, tmpfiles `/usr/local/bin/python3` rule,
  activation flag pinning, reminder, `installed_plugins.json` entry, doc). The
  Mac does not use it and NixOS follows the Mac's patterns. The `qbert.json`
  snapshot still lists it until `just bump-claude-skills` pulls a snapshot
  regenerated from claude-skills `feat/claude-stack-unify`; do not hand-edit it.
  Leftovers on already-deployed hosts (`~/.claude/plugins/data/token-optimizer-*`,
  the `/usr/local/bin/python3` symlink goes away on rebuild) can be deleted by hand.
- ralph-loop, reap, caveman: autonomous-loop engines duplicating `auto`
  (`/auto` 18 sessions vs 1-2), and caveman's terse-output ruleset contradicted
  the global "run all prose through humanizer" rule.

Marketplaces no longer registered because no non-absent plugin needs them:
`ai-marketplace`, `impeccable`, `hyperframes`.

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
genuinely runtime-owned file. When a plugin is dropped from the manifest (so
from the snapshot), prune its key from **both** copies in the same change, and
delete its `~/.claude/plugins/cache/<marketplace>/<plugin>/` directory too.
The repo copy is pruned in the PR that drops the plugin; the live copy and cache
are pruned by hand on each host, before the rebuild that runs activation:

```bash
# Per host, for each dropped <plugin>@<marketplace>. Keep set = every
# non-absent plugin id in that host's snapshot; the repo copy is a union over
# qbert and srv, so keep the union on both hosts.
f=~/.claude/plugins/installed_plugins.json
jq 'del(.plugins["<plugin>@<marketplace>"])' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
rm -rf ~/.claude/plugins/cache/<marketplace>/<plugin>
```

Phase 4 (manifest-driven plugins) dropped these ids, now pruned from the repo
copy; run the block above on qbert, srv and donkeykong for each, then `just qr`:

```
asana atlassian context7 feature-dev github kotlin-lsp learning-output-style
pr-review-toolkit rust-analyzer-lsp           (@claude-plugins-official)
commit feature-request kong-skill kong-skills (@kong-skills)
hyperframes@hyperframes  impeccable@impeccable  kong-konnect@ai-marketplace
```

After the rebuild, a second `just qr` must show no diff in
`config/plugins/installed_plugins.json` (the fixpoint check).
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

Most marketplaces pinned in the manifest trace to a recognizable
source (Kong, heygen-com, pbakaus, JuliusBrussee). A pin from a
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

The manifest records this as the marketplace's `review` field; the resolved
snapshot carries it. A SHA bump re-grants that trust wholesale. Re-run the same depth of review
(read every hook entrypoint and any auto-approval matcher in full, not just
a diff against the old SHA) before bumping a single-author marketplace,
and update the pin comment with what changed.

## 1Password vault: `automation`

One vault, the same refs as the Mac (donkeykong `Claudefile`). `secrets.json.tpl`
now reads `kong-konnect-pat/lab-pat-2026-06` and all four `Tableau-PAT` fields
(`hostname`, `Site-Name`, `username`, `credential`) from `op://automation/...`
instead of `op://nixerator/...`. The account that runs `just render-secrets`
(and `op inject`) must have read access to `automation`.

Still `op://nixerator/...` (not used by the Mac, no `automation` item known):
everything else in `secrets.json.tpl`, notably `context7/credential`. context7
needs the item created in the `automation` vault first, then the ref repointed.
