# Recipe Contract for `release-app`

The `release-app` skill calls into each registered app via a fixed Justfile
contract. Per-app variation (language, build system, signing, file paths)
lives inside the recipe; the skill itself never branches on app.

This file is the spec for that contract — read it when adding a new app to
the skill, or when modifying an existing app's release recipe.

## The contract

### Recipe signature

```just
quiet-release bump="patch":
```

- Recipe name: literally `quiet-release` (the skill calls `just quiet-release`
  with no fallback).
- Single positional argument `bump` accepting `patch`, `minor`, or `major`.
  Default `patch` if invoked bare.
- Reject anything else with a non-zero exit and a clear error to stderr.
  The skill never passes anything other than a bump keyword, but a hostile
  caller might.

### Computing the next version

The recipe is the source of truth for "what's the current version". Each
app may track this differently:

- File-anchored (e.g., `build.gradle.kts`, `pyproject.toml`, `Cargo.toml`)
- Git-anchored (`git describe --tags --abbrev=0`)
- Hybrid (file is canonical, tag is mirror)

Whichever it is, the recipe computes the next version itself by applying
`bump` to the current. The skill does *not* compute or pass an explicit
version — that would force every recipe to dual-handle bump-keyword and
explicit-version inputs, which is what the contract is meant to avoid.

### Side effects on success

A passing run must, in order:

1. Bump version in any source-of-truth files the app maintains
2. Build any release artifacts the app ships
3. Generate/refresh changelog if the app has one
4. Commit the version bump using `git commit -S` (explicitly signed)
5. Tag the commit `vX.Y.Z` using `git tag -s` (explicitly signed) and push
   the tag
6. Push the commit to `origin`
7. Create a GitHub release for the tag (with assets if appropriate)

Order matters — pushing before tagging risks orphaned commits; tagging
before push risks unpublished tags.

**Sign commits and tags explicitly.** Use `git commit -S` and `git tag -s`
rather than relying on `commit.gpgsign`/`tag.gpgsign` git config. Implicit
signing depends on the user's local config: a fresh clone, a CI runner,
or a different machine may have signing off and produce unsigned releases
silently. Explicit `-S`/`-s` fails loudly if signing isn't set up, which
is the right failure mode for a release.

### Required stdout output

On success, exactly one line of the form:

```
Released v<X.Y.Z>
```

This is the line the skill parses for the published version. The skill
takes the *last* match, so trailing diagnostic lines are fine. Anything
else on stdout is allowed; only this line is load-bearing.

### Required exit code

- Success: `0`
- Failure: non-zero

The skill keys off the exit code, not text. Don't print "FAILED" and exit
0; don't exit 1 on a successful but noisy run.

### Recommended on failure

When the recipe fails, write a log to `/tmp/<app>-release.log` and print
the path to stdout/stderr so the failure-diagnosis subagent has somewhere
to read. The skill falls back to `/tmp/<app>-release.log` if no path is
printed, so following this default keeps things zero-config.

A filtered error summary on stdout (top of the log piped through
`grep -i 'error|warning|fatal|failed|gpg:'`) helps the user see what went
wrong without opening the log.

## Template

Use this as a starting point. The version-computation block depends on
how the app tracks its current version — pick the right variant from the
"Variants" section below.

```just
# Quiet release — wraps the app's release recipe with output captured to a log.
# Accepts `patch` (default), `minor`, or `major` and computes the next version
# from the app's source-of-truth. Prints only milestones; on failure, filters
# errors and points to the log. Conforms to the `release-app` skill contract.
quiet-release bump="patch":
    #!/usr/bin/env bash
    set -uo pipefail
    log=/tmp/{{app_name}}-release.log

    # ── Validate bump ──
    case "{{bump}}" in
        patch|minor|major) ;;
        *)
            echo "Error: bump must be one of patch|minor|major (got '{{bump}}')." >&2
            exit 1
            ;;
    esac

    # ── Compute next version (pick a variant — see references/recipe-contract.md) ──
    # Variant: git-tag-anchored
    current=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
    if [[ -z "$current" || ! "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        echo "No prior semver tag found — defaulting current=0.0.0"
        current="0.0.0"
    fi
    IFS='.' read -r M m p <<< "$current"
    case "{{bump}}" in
        patch) version="$M.$m.$((p+1))" ;;
        minor) version="$M.$((m+1)).0" ;;
        major) version="$((M+1)).0.0" ;;
    esac

    # ── Run the real release recipe with output captured ──
    echo "Releasing v$version (quiet mode, bump={{bump}}, prev=v$current)..."
    rc=0
    # Replace the next line with however this app actually releases.
    just release "v$version" </dev/null &> "$log" || rc=$?

    # ── Report ──
    if [[ "$rc" -eq 0 ]]; then
        echo "Released v$version. Full log: $log"
    else
        filtered=$(grep -E -i '(^error|error:|warning:|trace:|fatal|FAILED|^FAILURE|gpg:|HTTP [45][0-9]{2})' "$log" | head -80)
        {
            echo "=== FILTERED ERRORS/WARNINGS ==="
            echo "$filtered"
            echo ""
            echo "=== FULL RELEASE LOG ==="
            cat "$log"
        } > "${log}.tmp"
        mv "${log}.tmp" "$log"
        echo "Release FAILED (exit $rc). Log: $log"
        echo "Use a subagent to diagnose $log and fix the issue."
        exit "$rc"
    fi
```

## Variants of the version-computation block

### Git-tag-anchored (Go, simple binary releases, anything tag-driven)

```bash
current=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//')
if [[ -z "$current" || ! "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    current="0.0.0"
fi
```

Used by: `meetsum`.

### File-anchored (Gradle / Kotlin / Java)

```bash
current=$(grep -oE '^version = "[0-9]+\.[0-9]+\.[0-9]+"' build.gradle.kts | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
```

Used by: `upsight` (the existing `release` recipe handles both bump-keyword
and explicit-version inputs; `quiet-release` wraps that).

### File-anchored (Python / pyproject.toml)

```bash
current=$(grep -oE '^version = "[0-9]+\.[0-9]+\.[0-9]+"' pyproject.toml | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
```

### File-anchored (Rust / Cargo.toml)

```bash
current=$(grep -oE '^version = "[0-9]+\.[0-9]+\.[0-9]+"' Cargo.toml | head -1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
```

### File-anchored (npm / package.json)

```bash
current=$(jq -r '.version' package.json)
```

## Reference implementations

- `~/git/upsight/Justfile` — Kotlin, Gradle, file-anchored, signed releases,
  uploads to two GitHub repos (public + customer).
- `~/git/meetsum/justfile` — Go, git-tag-anchored, single-repo release with
  cross-platform binaries.

When adding a new app, copy the closest reference and adapt.

## After adding the recipe

Once the recipe is in place and `just quiet-release patch` works end-to-end
on a dry run (consider doing it once with a dummy version to a personal
fork, or with the artifact-upload step temporarily commented out):

1. Open the `release-app` SKILL.md.
2. Append a row to the registry table with:
   - App key (short name)
   - Source repo absolute path
   - Downstream repo absolute path *or* `*(release-only — not yet wired ...)*`
   - Version anchor in the downstream repo *or* `—`
   - Lock-refresh command *or* `—`
   - Apply recipe *or* `—`
3. Run the skill once to verify.

If the app is release-only at first, the four downstream columns can be
filled in later — the skill detects "release-only" rows automatically and
short-circuits after the GitHub release.
