# claude-stack apply

`apps.cli.claude-code.stackApply.enable` hands the Claude Code settings to
claude-skills. The option still defaults to false; qbert and srv both set it
true (`hosts/qbert/modules.nix`, `hosts/srv/modules.nix`). This file is the
switch-on checklist, the rollback, and the list of nixerator copies that become
deletable afterwards.

Upstream plan: `docs/plans/central-claude-config-proposal.md` in claude-skills
(this is its phase 6) and `docs/plans/nixerator-to-claude-skills.md` beside it.
Schema and ownership rules: `docs/ai/claude-stack.md` there.

## What the switch changes

| | Off (today) | On |
| --- | --- | --- |
| Declared settings keys | 6 jq passes in `cfg/activation.nix` | one `claude_stack.py apply --write` call via `cfg/scripts/stack-apply.sh` |
| Resolved host file | `cfg/claude-stack/<host>.json`, hand-copied | `claude-stack/resolved/<host>.json` in the flake input |
| claude-skills marketplace sha | the `selfPins` literal in `cfg/plugin-config.nix` | the locked input's rev |
| `~/.claude/CLAUDE.md` | copied from `config/CLAUDE.md` | written by apply from `claude-stack/files/CLAUDE.md` |
| statusline body | `./statusline.sh` | `claude-stack/files/statusline.sh`, same Nix wrapper |
| `~/.claude/statusline.sh` | not deployed | written by apply (the Mac runs it directly; NixOS uses the wrapper) |
| PreCompact, UserPromptSubmit hooks | injected as Nix store paths | stripped; dk >= 3.6.0 ships both |
| `hooks.{PostToolUse,SessionStart,UserPromptSubmit,Stop}` | the repo `config/settings.json` list plus the jq injects | each list forced whole from the manifest, 14 rows, bodies supplied as `@VAR@` |
| Capture | carries every settings key back to the repo | drops the force-owned keys and the `claude-md` section |

Unchanged either way: `extraKnownMarketplaces`, `enabledPlugins`, `autoMode`,
`skillOverrides` (Nix-owned, not in `settings.force`), the add-only union of
the manifest's profile-level `permissions.allow`, `env.SSH_AUTH_SOCK` (the
manifest declares no value, because it is set or deleted per `serverProfile`),
and `hooks.PreToolUse` and `hooks.PreCompact`, which the manifest does not
declare.

Every hook body is byte-identical either way. The ten bodies that live in
`config/settings.json` reach apply as `@VAR@` values read out of that same
file at eval time (`default.nix`, `hookVarMarkers`), and the four Nix-built
hooks reach it as their store paths.

## Who owns which key, on

- **Manifest, replaced every apply.** `model`, `smallModelOverride`,
  `outputStyle`, `statusLine`, `attribution`, `coAuthor`,
  `includeCoAuthoredBy`, `cleanupPeriodDays`, `tui`, `env.PATH`,
  `env.XDG_RUNTIME_DIR`, `env.ANTHROPIC_DEFAULT_OPUS_MODEL`,
  `permissions.{deny,ask,defaultMode,additionalDirectories}`,
  `hooks.{PostToolUse,SessionStart,UserPromptSubmit,Stop}`, and nine UI and
  telemetry flags. A `/model` change is overwritten at the next rebuild.
- **Manifest, add-only.** `permissions.allow`. Declared rules are appended,
  live rules are never removed, and capture still round-trips them.
- **Nix.** The 17 `@VAR@` values, and the keys apply does not declare.
- **Never written.** `$schema`, `skipAutoPermissionPrompt`, `theme`, `voice`,
  `settings.local.json`, and all of `~/.claude.json`.

The 17 `@VAR@` values Nix supplies (`default.nix`, `stackVars`) are:

- Five Nix-built store paths: `STATUSLINE_COMMAND`,
  `GUARD_GENERATED_PATHS_HOOK`, `GUARD_RAW_NIX_HOOK`,
  `SESSION_REMINDERS_HOOK`, `GIT_SYNC_HOOK`.
- Ten hook bodies read out of `config/settings.json`: `NIX_FMT_HOOK`,
  `NIX_SECRET_SCAN_HOOK`, `NIX_LINT_HOOK`, `GUARD_NIXOS_REBUILD_HOOK`,
  `NIX_CONTENT_CHECK_HOOK`, `NIX_MODULE_STRUCTURE_HOOK`,
  `INTENT_LOG_PRUNE_HOOK`, `BRANCH_REPORT_HOOK`, `INTENT_LOG_APPEND_HOOK`,
  `STOP_NOTIFY_HOOK`. Each is matched on a command substring
  (`default.nix`, `hookVarMarkers`), not on a list index, and an assertion
  fails the build if a marker matches zero or several rows.
- `LINUX_PATH`, the `env.PATH` the manifest declares no value for.
- `XDG_RUNTIME_DIR`, which `cfg/scripts/stack-apply.sh` resolves from a real
  `id -u` at activation because Nix eval can run cross-host.

They go to apply in a 0600 file, never inline on the command line, where `ps`
would show them.

## Switch-on, per host

Both hosts are switched on in the repo already. This list is what to run on a
host that has not yet rebuilt with it, and what to re-run after a claude-skills
pin bump that touches `settings`, `files` or `vars`.

1. The pin must be a rev whose manifest declares all four hook events and the
   17 `linux` vars, and whose `claude-stack/files/` holds `CLAUDE.md` and
   `statusline.sh`. `just update claude-skills`. Two assertions fail with that
   message if it does not.
2. Dry-run apply by hand, from the pinned input, before any rebuild:
   `python3 <input>/scripts/claude_stack.py apply --host qbert --vars <vars.json>`.
   It writes nothing without `--write`. Build the vars file the way
   `cfg/scripts/stack-apply.sh` does (its `jq` line adds `XDG_RUNTIME_DIR` to
   the Nix-generated file), or read the store copy `claude-stack-vars.json` the
   next build produces. Nothing in the output may say `VAR_UNRESOLVED`: that
   means the manifest declares a var `stackVars` does not supply.
3. `apps.cli.claude-code.stackApply.enable = true` for that host, one host at a
   time. qbert sets it in `hosts/qbert/modules.nix` because `suites.ai` owns
   the rest of its `claude-code` block; srv sets it inside its own block at
   `hosts/srv/modules.nix`.
4. `just qr`. The first run prints
   `kept the pre-apply settings.json as settings.json.nix-backup`.
5. Verify: `claude_stack.py drift --host <host>`, then re-run `just qr` and
   confirm the second run makes no capture change.

Step 5 should report no FAIL. The `SETTINGS_MISMATCH` on `hooks.PostToolUse`
that earlier revisions expected is gone: the manifest now declares all eight
`PostToolUse` rows, so activation re-appends nothing and the live list matches
the declared one. The two rows it does not declare moved to dk >= 3.10.0,
`warn-default-branch.sh` and `guard-git-bypass.sh`. A `SETTINGS_MISMATCH` here
now means a real divergence, usually a `config/settings.json` hook edited
without updating the manifest row that declares it.

## Rollback

1. Set `apps.cli.claude-code.stackApply.enable = false`.
2. `just qr`. Activation rewrites `~/.claude/settings.json` from
   `config/settings.json` plus the jq merge, which is the pre-switch shape.
3. If a value is still wrong, `cp ~/.claude/settings.json.nix-backup
   ~/.claude/settings.json` and rebuild. That file is the settings.json from
   before the first apply on that host and is never overwritten.

The flake pin does not need reverting: with the option off, nothing reads the
input. `settings.json.nix-backup` is not captured (capture-sync walks
`skills`, `agents`, `output-styles`, `claude-md` and `settings.json` only).

## Deletable in phase 8, not before

Each line needs `claude_stack.py drift --host qbert` and `--host srv` clean, on
a host that has rebuilt with `stackApply` on.

| Path | Replaced by | Also delete |
| --- | --- | --- |
| `config/CLAUDE.md` | `claude-stack/files/CLAUDE.md` | the 8000-char assertion in `default.nix`, the `claude-md` capture section, `--section all-but-claude-md` |
| `config/settings.json` `permissions.allow` (158 rules) | manifest `permissions.allow` plus `settings.union` | needs `claude_stack.py promote` run first: 99 live rules are declared nowhere |
| `config/settings.json` force-owned keys (`env`, `model`, `statusLine`, `outputStyle`, `permissions.{deny,defaultMode,additionalDirectories}`, 9 flags) | `settings.force` | the `@STATUSLINE_COMMAND@` and `@USER_NAME@` sed in `cfg/activation.nix`, the matching capture canonicalization |
| `config/settings.json` `PostToolUse` rows 1 and 2 | dk `warn-default-branch.sh` and `guard-git-bypass.sh` | `rehomedRowMarkers` and `isRehomedRow` in `default.nix` |
| `config/settings.json` the other 6 `PostToolUse` rows, both `SessionStart` rows, the `Stop` row, the `UserPromptSubmit` row | the manifest rows that declare them | NOT deletable while `hookVarMarkers` reads their bodies out of this file. Move each body into dk or into the manifest first, then drop its `hookVarMarkers` entry and its `vars` entry together |
| `config/agents/{bash,devops,go,nix,slack-search}.md` | dk 3.6.0 `agents/` | the agents loop in `cfg/activation.nix`, the `agents` capture section |
| `config/output-styles/{dustin,compact}.md` | dk 3.6.0 `output-styles/` | the output-styles loop in `cfg/activation.nix`, the `output-styles` capture section |
| `output-styles/compact.md` (module root) | nothing, it is a dead copy referenced by no `.nix` | |
| `statusline.sh` | `claude-stack/files/statusline.sh` | the `statusLineSource` conditional and the SC1003 exclusion in `default.nix` |
| `cfg/scripts/precompact-checkpoint.sh`, `cfg/scripts/post-compact-reinject.sh` | dk 3.6.0 hooks | their `writeShellApplication` blocks, the strip clause in `cfg/activation.nix` |
| `cfg/claude-stack/{qbert,srv}.json` | the flake input | `cfg/scripts/bump-plugin-marketplace-sha.sh`, its bats, the `just bump-claude-skills` recipe, the `selfPins` literal, the `claudeSkillsSrc ? null` fallbacks |

`cfg/scripts/{git-sync,reminders,guard-generated-paths,guard-raw-nix}.sh` are
NOT on this list. All four stay Nix-built: the manifest references each one by
store path, as `@GIT_SYNC_HOOK@`, `@SESSION_REMINDERS_HOOK@`,
`@GUARD_GENERATED_PATHS_HOOK@` and `@GUARD_RAW_NIX_HOOK@`.

## Why the input is `git+ssh`

The repo is private. The `github:` fetcher authenticates with the nix
`access-tokens` setting, which comes from
`/run/nixos-secrets/nix-access-tokens.conf` at mode 0600 root. Rebuilds run as
root and would work; every user-level lock would not, including the
`.githooks` pre-commit `nix fmt`, `just build-host` and `nix flake check`. The
git+ssh fetcher shells out to git and uses the SSH agent, which the user has
and which `sudo --preserve-env=SSH_AUTH_SOCK nixos-rebuild` hands to root.
