---
name: release-app
description: >-
  Cut a release in an application repo and immediately propagate the new
  version into the workstation/consumer repo so it can be dogfooded. Runs
  the app's release recipe, captures the published version, updates the
  downstream repo's version anchor, commits + pushes via /commit, and
  rebuilds the workstation. Use whenever the user says "/release-app",
  "cut a release", "ship upsight", "release and dogfood", "release patch
  on upsight", "bump upsight on my workstation", "release X then update
  nixerator", or otherwise wants the end-to-end "publish a release →
  update my workstation to use it" loop. Trigger eagerly when the user is
  about to ship one of the apps in the registry below — this is the
  workflow they're describing, even if they don't name the skill.
---

# Release App

End-to-end "release the app, then dogfood it on the workstation" loop.

The skill assumes a two-repo pattern: a **source repo** that publishes
versioned releases, and a **downstream repo** (the workstation) that pins to
the source's version. After cutting the release, the version pin in the
downstream repo gets bumped, committed, pushed, and applied.

## Source Repo Convention

Every app in the registry MUST expose this Justfile contract — the skill
calls it the same way regardless of language or build system, so per-app
quirks live in the app's own Justfile rather than in this skill:

- **Recipe:** `just quiet-release <bump>` where `<bump>` is `patch`, `minor`,
  or `major`. The recipe is responsible for computing the next version from
  whatever source-of-truth it maintains (build.gradle.kts, git tags,
  pyproject.toml, …) and publishing the release end-to-end (build, tag,
  push, GitHub release).
- **Success output:** prints exactly one line of the form `Released
  v<X.Y.Z>` on stdout. The skill parses the *last* such line to learn the
  published version.
- **Failure behaviour:** non-zero exit. A failure log path printed to
  stdout is recommended (e.g., `Release FAILED. Log: /tmp/<app>-release.log`)
  so the failure-diagnosis subagent has somewhere to read.

When adding a new app whose Justfile doesn't yet conform, add a
`quiet-release` recipe to that app first — that's the supported way to
extend this skill. Upsight's `quiet-release` recipe is a good reference
implementation.

## App Registry

Adding a new app = append a row.

| App | Source repo | Downstream repo | Version anchor | Lock-refresh command | Apply recipe |
|-----|-------------|-----------------|----------------|----------------------|--------------|
| `upsight` | `~/git/upsight` | `~/git/nixerator` | `flake.nix` line `url = "github:bashfulrobot/upsight/vX.Y.Z";` under the `upsight` input | `nix flake lock --update-input upsight` | `just qr` |
| `meetsum` | `~/git/meetsum` | *(release-only — not yet wired into nixerator)* | — | — | — |

A row whose downstream half is `—` means **release-only**: the skill cuts
the release in the source repo and stops. When meetsum is later added to
nixerator, fill in the four blank columns and the propagation step kicks
in automatically — no other change to this skill is needed.

If the user invokes the skill from a CWD that doesn't match any source
repo in the registry, ask once for the missing fields, append a row, and
proceed. Don't try to infer the version anchor silently — getting it wrong
will desync the workstation.

## Invocation

```
/release-app [<app>] [<level>]
```

- `<app>` — registry key. Defaults to the registry entry whose `Source repo`
  matches the current working directory.
- `<level>` — `patch` | `minor` | `major` | explicit semver `X.Y.Z`. If
  omitted, recommend a level from the conventional-commit log between the
  last tag and `HEAD`, then proceed without further confirmation.

Recommendation logic when `<level>` is omitted:

- Any commit subject contains `BREAKING CHANGE` or `!:` → `major`
- Otherwise any `feat:` or `feat(...):` → `minor`
- Otherwise → `patch`

State the recommended level and the rationale in one line, then proceed.

## Why both repos must be clean and in sync first

The user explicitly flagged this. The reason: the release recipe pushes to
the source remote and tags it; if the local source is *behind* origin, the
release commit gets built against a stale base and the push will be
rejected. If the downstream repo is *behind* origin, the version-bump
commit lands on top of out-of-date config and risks merge conflicts that
get noticed only at `just qr` time, after the release is already public.

So: fetch and check both, *before touching either*.

## Step 1: Pre-flight

If the registry row has no downstream (release-only), only check the
source repo. Skip every downstream check and skip Steps 4–7 entirely.

For each repo to check (always source; downstream only if configured):

```bash
git -C <repo> fetch --all --tags --prune
git -C <repo> status --porcelain
git -C <repo> rev-list --left-right --count "@{u}...HEAD"
```

Decision rules per repo:

- **Working tree dirty** (`status --porcelain` non-empty)
  - For source: stop. The release recipe will refuse non-interactively. Ask
    the user to commit/stash, then re-invoke.
  - For downstream: stop. Bumping on top of unrelated dirty state would
    conflate concerns in the commit and confuse `/commit`.
- **Behind origin** (left side of `rev-list` count > 0): stop. Tell the
  user, suggest `git pull --rebase`, do not auto-pull (they may have a
  local reason for the divergence).
- **Ahead of origin** (right side > 0):
  - Source: warn but proceed — the release recipe will push everything.
  - Downstream: warn and ask. Unpushed commits in the workstation repo
    are unusual and may collide with the bump commit.

If pre-flight fails, do not silently skip a repo. Stop, surface what's
wrong on each, suggest the fix, and exit.

## Step 2: Cut the release in the source repo

```bash
cd <source>
just quiet-release <level>
```

The recipe handles version bump, build, changelog, commit, tag, push, and
GitHub release in one shot. Do not try to do these steps manually — the
recipe is the source of truth.

### If the recipe fails

By convention, a conforming `quiet-release` writes its log to
`/tmp/<app>-release.log` and prints the path on failure (e.g., the failure
message includes "Log: /tmp/<app>-release.log"). On non-zero exit, parse
the log path from the recipe's stderr/stdout — fall back to
`/tmp/<app>-release.log` if not printed — and **dispatch a general-purpose
subagent** to diagnose it:

```
Agent({
  description: "Diagnose release failure",
  subagent_type: "general-purpose",
  prompt: "The `just quiet-release <level>` recipe in <source> failed.
  Read <log path>, identify the root cause, and propose a concrete fix.
  Common causes: signing key not loaded (gpg:), GitHub auth, dirty tree,
  build failure. Return the cause and the smallest fix that unblocks the
  release. Do not run the release yourself."
})
```

Apply the fix, re-run the recipe. If two attempts don't make progress,
stop the skill and report to the user — do not loop indefinitely.

## Step 3: Capture the released version

The convention guarantees the recipe prints a single line of the form
`Released v<X.Y.Z>` on success. Parse the *last* such line from the
recipe's stdout:

```bash
version=$(printf '%s\n' "$RECIPE_STDOUT" | grep -oP 'Released v\K[0-9]+\.[0-9]+\.[0-9]+' | tail -1)
```

If `$version` is empty, do not guess. Stop and report — the bump in the
downstream repo must reference a version that actually exists on the
source remote.

Confirm the new tag is present in the source repo:

```bash
git -C <source> fetch --tags
git -C <source> tag --list "v$version"
```

If absent, stop — the recipe printed success but the tag isn't there;
something is wrong.

**If this row is release-only**, skip directly to Step 8 with `version`
in hand and the downstream half of the report omitted.

## Step 4: Bump the version anchor in the downstream repo

```bash
cd <downstream>
```

Locate the line described by the registry's `Version anchor` and rewrite
it to the new version. For upsight in nixerator:

```bash
sed -i -E "s|github:bashfulrobot/upsight/v[0-9]+\.[0-9]+\.[0-9]+|github:bashfulrobot/upsight/v${version}|" flake.nix
```

Verify the edit landed exactly once:

```bash
grep -nE 'github:bashfulrobot/upsight/v[0-9]+\.[0-9]+\.[0-9]+' flake.nix
```

If zero or multiple matches, stop — the anchor is ambiguous, do not guess.

Then run the lock-refresh command from the registry:

```bash
nix flake lock --update-input upsight
```

This updates `flake.lock` to point at the new tag's commit. Without it, the
build at Step 7 will keep using the previous version even though
`flake.nix` says otherwise.

## Step 5: Commit via `/commit`

Invoke the commit skill:

```
Skill(skill: "commit")
```

The /commit skill produces a conventional commit message from the staged
diff. Stage the relevant files first so it picks up the right scope:

```bash
git -C <downstream> add flake.nix flake.lock
```

For upsight in nixerator the resulting commit message should look roughly
like `chore(deps): bump upsight to v<version>`. Don't author the message
yourself — let `/commit` do it.

## Step 6: Push the bump commit

```bash
git -C <downstream> push
```

If the push is rejected (e.g., remote moved between pre-flight and now),
stop. Don't auto-rebase — the user might have intentional unrelated work
landing concurrently.

## Step 7: Apply via the apply recipe

```bash
cd <downstream>
just qr        # substitute the registry's apply recipe
```

For nixerator, `just qr` is the host-agnostic rebuild — it picks up the
new flake input and applies the configuration to the current host. This is
the dogfooding step: when this returns success, the workstation is
running the new release.

If the apply fails, leave the commit in place (it is correct — the new
version exists), surface the error, and let the user decide whether to
roll back or fix forward. Do not auto-revert.

## Step 8: Final report

For an app with downstream propagation:

```
Released <app> v<version> and applied to <downstream>.

Source:     <source repo>  →  pushed v<version>, GitHub release created
Downstream: <downstream>   →  version anchor bumped, committed, pushed, rebuilt

Commits:
  <source>: <release-commit-sha>
  <downstream>: <bump-commit-sha>
```

For a release-only app:

```
Released <app> v<version>.

Source: <source repo>  →  pushed v<version>, GitHub release created

(No downstream propagation configured for this app. Add the four blank
columns to the registry once <app> is wired into a workstation repo.)

Commits:
  <source>: <release-commit-sha>
```

If anything was skipped or warned (ahead-of-remote, recipe retry, lock
refresh edge case), call it out at the end of the report so it isn't lost.

## Adding a new app to the registry

The full spec — recipe signature, required stdout, exit codes, log file
conventions, copy-pasteable Justfile template, and version-computation
variants for several languages — lives in
[`references/recipe-contract.md`](references/recipe-contract.md). Read it
when adding a new app or auditing an existing recipe; it's the source of
truth for the contract.

Quick path:

1. **Confirm the source repo conforms to the recipe contract** — does it
   expose `just quiet-release <bump>` printing `Released v<X.Y.Z>`? If
   not, add the recipe first using the template in `references/recipe-contract.md`.
   Don't work around a missing recipe — make the app conform.
2. Once the recipe is in place, gather these fields. **If `$CLAUDE_AUTO_MODE` is set** (autonomous run via `/auto`), use the safest defaults below and skip the prompt; otherwise gather via `AskUserQuestion`.

   **Auto-mode defaults:**
   - Version bump: `patch` (never minor/major in autonomous runs)
   - Release notes: auto-generated from commit log since last tag
   - Dogfood after release: yes
   - Push to remote: yes
   - If any required field has no safe default in your context (e.g. an unrecognised app), abort the autonomous run with a blocked-reason report rather than guessing.

   **Interactive gathering** (when `$CLAUDE_AUTO_MODE` unset):
   1. Registry key (short name)
   2. Source repo absolute path
   3. Downstream repo absolute path — or skip if release-only
   4. Version anchor (the file + pattern where the version pin lives —
      e.g., "flake.nix line `<input>.url = "...vX.Y.Z";`", or
      "Cargo.toml `[dependencies] foo = "X.Y.Z"`")
   5. Lock-refresh command (empty if unneeded)
   6. Apply recipe

Append the row to the registry table in this SKILL.md, then proceed with
the workflow. Mention to the user that the skill now knows about the new
app for future runs.

## Why this skill is structured around a registry

A two-repo release loop has a small, fixed set of variables: where each
repo lives, the recipe to release, the recipe to apply, and the literal
text where the version pin lives. The actions in between (cut → capture
→ rewrite → commit → push → rebuild) are identical across apps. A
registry table is the smallest representation that lets the workflow be
generic without speculative abstraction — and crucially, it surfaces the
*one* thing that's genuinely app-specific (the version anchor) where it
can be reviewed and edited as a value, not as code.
