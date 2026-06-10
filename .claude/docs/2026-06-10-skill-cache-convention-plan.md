# skill-cache Convention Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a reusable warm-cache convention — a Nix-packaged `skill-cache` CLI plus a documented file-format contract — that query skills adopt to cache name→ID identity mappings and slow-changing metadata instead of re-resolving them every run.

**Architecture:** One canonical bash script (`scripts/skill-cache.sh`) is wrapped by `writeShellApplication` into a system CLI for internal skills, and is vendorable verbatim into portable/marketplace skills. Cache data lives as per-skill JSON under `$XDG_CACHE_HOME/claude-skills/<skill>.json` (outside the Nix tree, so `just qr` never reverts it). A `.claude/docs/skill-cache.md` contract plus two `CLAUDE.md` TOC triggers make the convention discoverable when authoring skills inside or outside this repo.

**Tech Stack:** bash, jq 1.8.1 (uses `now`/`fromdateiso8601`/`todateiso8601` — no `date` dependency), Nix `writeShellApplication`, bats for unit tests, just for the test/rebuild entry points.

Design source: `.claude/docs/2026-06-10-skill-cache-convention-design.md`.

---

## File Structure

| File | Responsibility |
|------|----------------|
| `modules/apps/cli/skill-cache/scripts/skill-cache.sh` | The CLI logic. Standalone-runnable (own shebang + `set`), dependency-free beyond bash/jq/coreutils. Single source of truth, also the vendor copy-source. |
| `modules/apps/cli/skill-cache/tests/helper.bash` | bats helper: resolves the script path, runs it against a per-test temp `XDG_CACHE_HOME`. |
| `modules/apps/cli/skill-cache/tests/skill-cache.bats` | bats unit tests for get/put/forget/list/path, TTL expiry, aliases, normalization, corrupt-file tolerance. |
| `modules/apps/cli/skill-cache/default.nix` | Nix module: `writeShellApplication` + `apps.cli.skill-cache.enable` option → `environment.systemPackages`. |
| `modules/suites/ai/default.nix` | Flip `skill-cache.enable = true` alongside `claude-code`. |
| `justfile` | New `test-skill-cache` recipe wrapping bats. |
| `.claude/docs/skill-cache.md` | The runtime-facing contract: schema, tiers, CLI reference, embedded-block template, when-to-adopt checklist, "add a table" recipe, vendoring instructions. |
| `CLAUDE.md` (project root) | Reference TOC entry (nixerator-relative). |
| `modules/apps/cli/claude-code/config/CLAUDE.md` | Authoring-trigger TOC entry (absolute doc path; deployed to `~/.claude/CLAUDE.md`). |

---

## Task 1: Canonical `skill-cache` script + bats tests (TDD)

**Files:**
- Create: `modules/apps/cli/skill-cache/tests/helper.bash`
- Create: `modules/apps/cli/skill-cache/tests/skill-cache.bats`
- Create: `modules/apps/cli/skill-cache/scripts/skill-cache.sh`
- Modify: `justfile` (add `test-skill-cache` recipe)

- [ ] **Step 1: Write the bats helper**

Create `modules/apps/cli/skill-cache/tests/helper.bash`:

```bash
# Shared bats helper for skill-cache. Resolves the script and runs it against a
# per-test temp XDG_CACHE_HOME so tests never touch the real cache.
TESTS_DIR="$(cd "$(dirname "${BATS_TEST_FILENAME}")" && pwd)"
SCRIPT="$(cd "${TESTS_DIR}/.." && pwd)/scripts/skill-cache.sh"

setup_xdg() { XDG="$(mktemp -d)"; }
rm_xdg() { [ -n "${XDG:-}" ] && rm -rf "${XDG}"; }

# sc — run the script with the test's isolated cache home.
sc() { XDG_CACHE_HOME="${XDG}" bash "${SCRIPT}" "$@"; }
```

- [ ] **Step 2: Write the failing tests**

Create `modules/apps/cli/skill-cache/tests/skill-cache.bats`:

```bash
#!/usr/bin/env bats
load helper

setup() { setup_xdg; }
teardown() { rm_xdg; }

@test "put then get round-trips an identity value" {
  sc put todoist projects "Road Map" '{"id":"123"}'
  run sc get todoist projects "road map"
  [ "$status" -eq 0 ]
  [ "$output" = '{"id":"123"}' ]
}

@test "get on a missing key exits 3" {
  run sc get todoist projects nope
  [ "$status" -eq 3 ]
}

@test "lookup is case- and whitespace-insensitive" {
  sc put aha customers "Acme Corp" '{"portal":"PROD"}'
  run sc get aha customers "  acme   corp "
  [ "$status" -eq 0 ]
  [ "$output" = '{"portal":"PROD"}' ]
}

@test "alias resolves to the same entry" {
  sc put aha customers acme-corp '{"portal":"PROD"}' --alias "Acme" --alias "ACME Corporation"
  run sc get aha customers "acme corporation"
  [ "$status" -eq 0 ]
  [ "$output" = '{"portal":"PROD"}' ]
}

@test "identity entry is stored with null expiry (listed as identity)" {
  sc put aha customers acme '{"portal":"PROD"}'
  run sc list aha customers
  [ "$status" -eq 0 ]
  [[ "$output" == *"acme"* ]]
  [[ "$output" == *"identity"* ]]
}

@test "expired metadata entry exits 4; --allow-stale returns it" {
  sc put aha customers acme '{"portal":"PROD"}' --ttl 1d
  f="$(sc path aha)"
  tmp="$(mktemp)"
  jq '.tables.customers.acme.expires_at = "2000-01-01T00:00:00Z"' "$f" > "$tmp"
  mv "$tmp" "$f"
  run sc get aha customers acme
  [ "$status" -eq 4 ]
  run sc get aha customers acme --allow-stale
  [ "$status" -eq 0 ]
  [ "$output" = '{"portal":"PROD"}' ]
}

@test "metadata entry within TTL is fresh" {
  sc put aha customers acme '{"portal":"PROD"}' --ttl 30d
  run sc get aha customers acme
  [ "$status" -eq 0 ]
  [ "$output" = '{"portal":"PROD"}' ]
}

@test "forget a key removes it" {
  sc put todoist projects work '{"id":"1"}'
  sc forget todoist projects work
  run sc get todoist projects work
  [ "$status" -eq 3 ]
}

@test "forget a whole table removes all its keys" {
  sc put todoist projects work '{"id":"1"}'
  sc put todoist projects home '{"id":"2"}'
  sc forget todoist projects
  run sc get todoist projects work
  [ "$status" -eq 3 ]
  run sc get todoist projects home
  [ "$status" -eq 3 ]
}

@test "put rejects an invalid JSON value" {
  run sc put todoist projects work 'not-json'
  [ "$status" -eq 2 ]
}

@test "a corrupt cache file is treated as a miss, not an error" {
  mkdir -p "${XDG}/claude-skills"
  printf 'garbage{' > "${XDG}/claude-skills/aha.json"
  run sc get aha customers acme
  [ "$status" -eq 3 ]
}

@test "path prints the per-skill cache file location" {
  run sc path aha
  [ "$status" -eq 0 ]
  [ "$output" = "${XDG}/claude-skills/aha.json" ]
}

@test "bad --ttl is rejected" {
  run sc put aha customers acme '{"x":1}' --ttl 5x
  [ "$status" -eq 2 ]
}
```

- [ ] **Step 3: Run tests to verify they fail**

Run: `nix shell nixpkgs#bats nixpkgs#jq --command bats modules/apps/cli/skill-cache/tests/`
Expected: FAIL — every test errors because `scripts/skill-cache.sh` does not exist yet.

- [ ] **Step 4: Write the canonical script**

Create `modules/apps/cli/skill-cache/scripts/skill-cache.sh`:

```bash
#!/usr/bin/env bash
# skill-cache — warm cache for query skills.
#
# Stores per-skill identity mappings and slow-changing metadata as JSON at
# $XDG_CACHE_HOME/claude-skills/<skill>.json. Depends only on bash + jq +
# coreutils, so it can be vendored verbatim into a portable skill as
# scripts/skill-cache.sh. Under Nix it is wrapped by writeShellApplication,
# which re-applies the shebang and `set` harmlessly (a second shebang line is
# just a comment to shellcheck).
set -euo pipefail

VERSION="1"

usage() {
  cat <<'EOF'
skill-cache — warm cache for query skills

Usage:
  skill-cache get    <skill> <table> <key> [--allow-stale]
  skill-cache put    <skill> <table> <key> <json-value> [--ttl DURATION] [--alias NAME]...
  skill-cache forget <skill> <table> [<key>]
  skill-cache list   <skill> [<table>] [--json]
  skill-cache path   <skill>

get exit codes: 0 fresh hit, 3 miss, 4 expired (unless --allow-stale).
--ttl DURATION is <n>h or <n>d (e.g. 12h, 7d, 30d). Omit --ttl to store an
identity entry that never expires. Keys match case-insensitively with
whitespace collapsed; register extra lookup names with repeated --alias.
EOF
}

die() { echo "skill-cache: $*" >&2; exit 2; }

cache_dir() { printf '%s' "${XDG_CACHE_HOME:-$HOME/.cache}/claude-skills"; }

cache_file() {
  [ -n "${1:-}" ] || die "missing <skill>"
  printf '%s/%s.json' "$(cache_dir)" "$1"
}

# normalize: lowercase, collapse whitespace runs to one space, trim ends.
norm() {
  local s
  s="$(printf '%s' "${1:-}" | tr '[:upper:]' '[:lower:]' | tr -s '[:space:]' ' ')"
  s="${s# }"; s="${s% }"
  printf '%s' "$s"
}

# echo the cache JSON, or an empty skeleton when the file is missing/corrupt.
read_cache() {
  if [ -f "$1" ] && jq -e . "$1" >/dev/null 2>&1; then
    cat "$1"
  else
    printf '{"schema":%s,"tables":{}}' "$VERSION"
  fi
}

# atomic write via tempfile + mv in the same directory.
write_cache() {
  local dir tmp
  dir="$(dirname "$1")"
  mkdir -p "$dir"
  tmp="$(mktemp "$dir/.skill-cache.XXXXXX")"
  printf '%s\n' "$2" > "$tmp"
  mv -f "$tmp" "$1"
}

# duration (<n>h|<n>d) -> seconds. Forces base-10 to avoid octal on leading 0.
ttl_seconds() {
  local d="$1" num unit
  case "$d" in
    *[!0-9hd]* | "") die "bad --ttl '$d' (use <n>h or <n>d)";;
  esac
  num="${d%[hd]}"
  unit="${d##*[0-9]}"
  [ -n "$num" ] || die "bad --ttl '$d' (use <n>h or <n>d)"
  case "$unit" in
    h) printf '%s' "$(( 10#$num * 3600 ))";;
    d) printf '%s' "$(( 10#$num * 86400 ))";;
    *) die "bad --ttl '$d' (use <n>h or <n>d)";;
  esac
}

cmd="${1:-}"; [ -n "$cmd" ] || { usage; exit 2; }
shift || true

case "$cmd" in
  -h|--help|help) usage; exit 0;;

  get)
    allow_stale=0
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --allow-stale) allow_stale=1;;
        -*) die "unknown flag for get: $1";;
        *) args+=("$1");;
      esac
      shift
    done
    [ "${#args[@]}" -eq 3 ] || die "usage: get <skill> <table> <key>"
    skill="${args[0]}"; table="${args[1]}"; nkey="$(norm "${args[2]}")"
    f="$(cache_file "$skill")"
    entry="$(read_cache "$f" | jq -c --arg t "$table" --arg k "$nkey" '
      (.tables[$t] // {}) as $tbl
      | ($tbl[$k] // ([ $tbl | to_entries[]
          | select((.value.aliases // []) | index($k)) | .value ] | first))
    ')"
    if [ -z "$entry" ] || [ "$entry" = "null" ]; then exit 3; fi
    status="$(printf '%s' "$entry" | jq -r '
      .expires_at as $e
      | if $e == null then "fresh"
        elif ($e | fromdateiso8601) > now then "fresh"
        else "expired" end')"
    if [ "$status" = "expired" ] && [ "$allow_stale" -eq 0 ]; then exit 4; fi
    printf '%s' "$entry" | jq -c '.value'
    ;;

  put)
    ttl=""
    aliases='[]'
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --ttl) shift; ttl="${1:-}"; [ -n "$ttl" ] || die "--ttl needs a value";;
        --alias)
          shift; [ -n "${1:-}" ] || die "--alias needs a value"
          aliases="$(printf '%s' "$aliases" | jq -c --arg a "$(norm "$1")" '. + [$a] | unique')";;
        -*) die "unknown flag for put: $1";;
        *) args+=("$1");;
      esac
      shift
    done
    [ "${#args[@]}" -eq 4 ] || die "usage: put <skill> <table> <key> <json-value> [--ttl D] [--alias N]..."
    skill="${args[0]}"; table="${args[1]}"; nkey="$(norm "${args[2]}")"; value="${args[3]}"
    printf '%s' "$value" | jq -e . >/dev/null 2>&1 || die "<json-value> is not valid JSON"
    if [ -n "$ttl" ]; then ttlsec="$(ttl_seconds "$ttl")"; else ttlsec="null"; fi
    f="$(cache_file "$skill")"
    new="$(read_cache "$f" | jq -c \
      --arg t "$table" --arg k "$nkey" \
      --argjson v "$value" --argjson aliases "$aliases" --argjson ttl "$ttlsec" '
      .tables[$t] = (.tables[$t] // {})
      | .tables[$t][$k] = {
          value: $v,
          aliases: $aliases,
          cached_at: (now | todateiso8601),
          expires_at: (if $ttl == null then null else ((now + $ttl) | todateiso8601) end)
        }')"
    write_cache "$f" "$new"
    ;;

  forget)
    [ $# -ge 2 ] || die "usage: forget <skill> <table> [<key>]"
    skill="$1"; table="$2"; key="${3:-}"
    f="$(cache_file "$skill")"
    if [ -n "$key" ]; then
      nkey="$(norm "$key")"
      new="$(read_cache "$f" | jq -c --arg t "$table" --arg k "$nkey" '
        if .tables[$t] then .tables[$t] |= del(.[$k]) else . end')"
    else
      new="$(read_cache "$f" | jq -c --arg t "$table" 'del(.tables[$t])')"
    fi
    write_cache "$f" "$new"
    ;;

  list)
    as_json=0
    args=()
    while [ $# -gt 0 ]; do
      case "$1" in
        --json) as_json=1;;
        -*) die "unknown flag for list: $1";;
        *) args+=("$1");;
      esac
      shift
    done
    [ "${#args[@]}" -ge 1 ] || die "usage: list <skill> [<table>] [--json]"
    skill="${args[0]}"; table="${args[1]:-}"
    f="$(cache_file "$skill")"
    data="$(read_cache "$f")"
    if [ "$as_json" -eq 1 ]; then
      if [ -n "$table" ]; then
        printf '%s' "$data" | jq --arg t "$table" '.tables[$t] // {}'
      else
        printf '%s' "$data" | jq '.'
      fi
    elif [ -n "$table" ]; then
      printf '%s' "$data" | jq -r --arg t "$table" '
        (.tables[$t] // {}) | to_entries[]
        | "\(.key)\t\(.value.expires_at // "identity")"'
    else
      printf '%s' "$data" | jq -r '
        .tables | to_entries[] as $t
        | $t.value | to_entries[]
        | "\($t.key)\t\(.key)\t\(.value.expires_at // "identity")"'
    fi
    ;;

  path)
    [ $# -eq 1 ] || die "usage: path <skill>"
    printf '%s\n' "$(cache_file "$1")"
    ;;

  *) die "unknown command '$cmd' (try --help)";;
esac
```

- [ ] **Step 5: Add the `just test-skill-cache` recipe**

Append to `justfile` (placement is not order-sensitive in just; put it near the other check recipes):

```just
# Run skill-cache unit tests
test-skill-cache:
    nix shell nixpkgs#bats nixpkgs#jq --command bats modules/apps/cli/skill-cache/tests/
```

- [ ] **Step 6: Run tests to verify they pass**

Run: `just test-skill-cache`
Expected: PASS — all 13 tests green.

- [ ] **Step 7: Commit**

```bash
git add modules/apps/cli/skill-cache/scripts/skill-cache.sh \
        modules/apps/cli/skill-cache/tests/helper.bash \
        modules/apps/cli/skill-cache/tests/skill-cache.bats \
        justfile
git commit -m "feat(skill-cache): add warm-cache CLI script with bats tests"
```

---

## Task 2: Nix module + enable

**Files:**
- Create: `modules/apps/cli/skill-cache/default.nix`
- Modify: `modules/suites/ai/default.nix` (cli block)

- [ ] **Step 1: Write the module**

Create `modules/apps/cli/skill-cache/default.nix`:

```nix
{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.skill-cache;
  skill-cache = pkgs.writeShellApplication {
    name = "skill-cache";
    runtimeInputs = with pkgs; [
      jq
      coreutils
    ];
    text = builtins.readFile ./scripts/skill-cache.sh;
  };
in
{
  options.apps.cli.skill-cache.enable = lib.mkOption {
    type = lib.types.bool;
    default = false;
    description = "Enable skill-cache — warm cache CLI for query skills.";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ skill-cache ];
  };
}
```

- [ ] **Step 2: Enable it in the AI suite**

In `modules/suites/ai/default.nix`, inside `config.apps.cli`, add the enable line next to the other tools (e.g. after `skillfish.enable = true;`):

```nix
        skill-cache.enable = true;
```

- [ ] **Step 3: Format and lint the Nix**

Run: `just fmt`
Then: `just health`
Expected: formatting clean; deadnix/statix report nothing new for the added files.

- [ ] **Step 4: Rebuild to verify the package builds**

Run: `just qr`
Expected: rebuild succeeds. `writeShellApplication` runs `shellcheck` on the script during the build — a green build confirms the script is shellcheck-clean (including the in-body shebang being treated as a comment).

- [ ] **Step 5: Verify the CLI is on PATH and works end-to-end**

Run:
```bash
skill-cache put smoke t demo '{"ok":true}' && skill-cache get smoke t demo && skill-cache forget smoke t && rm -f "$(skill-cache path smoke)"
```
Expected: prints `{"ok":true}`, exit 0; cleanup leaves no `smoke.json`.

- [ ] **Step 6: Commit**

```bash
git add modules/apps/cli/skill-cache/default.nix modules/suites/ai/default.nix
git commit -m "feat(skill-cache): package CLI as a Nix module and enable in AI suite"
```

---

## Task 3: The convention contract doc

**Files:**
- Create: `.claude/docs/skill-cache.md`

- [ ] **Step 1: Write the contract doc**

Create `.claude/docs/skill-cache.md`:

```markdown
# skill-cache — warm-cache convention for query skills

A shared cache for the identifiers and slow-changing metadata that query skills
otherwise re-resolve on every run (customer → Aha portal id, project name →
Todoist id, account name → SFDC Account Id). Backed by the `skill-cache` CLI;
data lives at `${XDG_CACHE_HOME:-$HOME/.cache}/claude-skills/<skill>.json`.

## When to adopt (and when NOT to)

Adopt when the skill:
- resolves a human name → a stable id/reference on most invocations, or
- repeatedly reads slow-changing metadata (owner, segment, custom-field keys).

Do NOT adopt for:
- one-shot skills that don't re-resolve anything,
- write-only skills,
- skills whose only data is live state (status, counts, due dates, case state) —
  that must always be fetched fresh.

## The two tiers

- **Identity** — name→id/reference that effectively never changes. Store with no
  TTL; it never expires. Re-resolve only on an explicit miss or after `forget`.
- **Slow metadata** — changes rarely (owner, segment, custom-field keys). Store
  with `--ttl` (e.g. `7d`, `30d`); it auto-expires and is re-fetched.

**Never cache live state.** Status, counts, due dates, case state — always fetch
fresh, never `put` them.

## CLI reference

    skill-cache get    <skill> <table> <key> [--allow-stale]
    skill-cache put    <skill> <table> <key> <json-value> [--ttl 7d] [--alias NAME]...
    skill-cache forget <skill> <table> [<key>]
    skill-cache list   <skill> [<table>] [--json]
    skill-cache path   <skill>

- `get` exits 0 + prints the value JSON on a fresh hit, 3 on a miss, 4 on an
  expired entry (unless `--allow-stale`, which prints the stale value and exits
  0). A non-zero exit is the signal to call the API.
- `put` with no `--ttl` stores an identity entry; `--ttl <n>{h,d}` stores a
  metadata entry. `--alias` (repeatable) registers extra lookup names.
- `forget <skill> <table> <key>` deletes one entry; omit `<key>` to drop the
  whole table. This is the refresh action: forget, then re-resolve.
- Keys match case-insensitively with internal whitespace collapsed.
- A missing or corrupt cache file is treated as empty — the cache is an
  optimization, never a correctness dependency.

## Schema

One file per skill; `tables` group logical record types:

    {
      "schema": 1,
      "tables": {
        "customers": {
          "acme-corp": {
            "value": { "portal_id": "PROD", "ref_prefix": "DEVP" },
            "aliases": ["acme", "acme corporation"],
            "cached_at": "2026-06-10T16:00:00Z",
            "expires_at": null
          }
        }
      }
    }

`expires_at: null` = identity tier; an ISO-8601 timestamp = metadata tier.

## The block to embed in an adopting SKILL.md

> **Before** resolving a `<thing>` → `<id>`, run
> `skill-cache get <skill> <table> <key>` (vendored skills:
> `bash scripts/skill-cache.sh …`). On a hit, use the cached value — **no API
> call**. On miss/expired, resolve via the API, then `skill-cache put …`. Cache
> only stable identity (no `--ttl`) and slow metadata (`--ttl`). **Never** cache
> live state. If the user says the cache is wrong or stale,
> `skill-cache forget` the key and re-resolve.

## Add a table to a skill (recipe)

1. Pick a `<table>` name for the record type (`customers`, `projects`,
   `accounts`).
2. In the skill's resolve step, call `skill-cache get <skill> <table> <key>`
   first; on non-zero exit, hit the API.
3. After resolving, `skill-cache put <skill> <table> <key> '<json>'` — add
   `--ttl 30d` for metadata, omit it for identity, add `--alias` for known
   alternate names.
4. Embed the block above in the SKILL.md.

Worked tables:
- **aha** `customers`: identity = portal id, ref prefix, custom-field keys;
  metadata (`--ttl 30d`) = CSM owner, segment.
- **todoist** `projects`: identity = project id, section ids, label ids.
- **sfdc** `accounts`: identity = Account Id; metadata (`--ttl`) = owner, region.

## Portable / marketplace skills

Internal skills use the Nix-packaged `skill-cache` on PATH. A skill published to
the corporate marketplace cannot assume the CLI exists, so it **vendors a copy**:

    cp /home/dustin/git/nixerator/modules/apps/cli/skill-cache/scripts/skill-cache.sh \
       <skill>/scripts/skill-cache.sh

The script is self-contained (own shebang, needs only bash + jq + coreutils) and
computes its own cache path, so it runs unchanged on a teammate's machine. Call
it as `bash scripts/skill-cache.sh …`. Re-copy from the canonical source to pick
up fixes.
```

- [ ] **Step 2: Commit**

```bash
git add .claude/docs/skill-cache.md
git commit -m "docs(claude-code): add skill-cache convention contract"
```

---

## Task 4: Discoverability — CLAUDE.md triggers

**Files:**
- Modify: `CLAUDE.md` (project root, Topics section)
- Modify: `modules/apps/cli/claude-code/config/CLAUDE.md` (global, deployed to `~/.claude/CLAUDE.md`)

- [ ] **Step 1: Add the reference TOC entry to the project CLAUDE.md**

In `/home/dustin/git/nixerator/CLAUDE.md`, under `## Topics`, add a bullet (keep the existing imperative style):

```markdown
- When a skill repeatedly resolves names→IDs or re-queries an external API for the same data, read `.claude/docs/skill-cache.md` for the warm-cache convention and the `skill-cache` CLI.
```

- [ ] **Step 2: Add the authoring trigger to the global CLAUDE.md**

In `modules/apps/cli/claude-code/config/CLAUDE.md`, add a new short subsection near the "Where curated knowledge goes" guidance:

```markdown
## skill-cache convention

When creating or modifying a skill that resolves names→IDs or repeatedly queries
an external API, read `/home/dustin/git/nixerator/.claude/docs/skill-cache.md`
and consider adopting the `skill-cache` convention. For a skill that will be
shared/published, vendor `scripts/skill-cache.sh` from the canonical source named
in that doc rather than depending on the packaged CLI.
```

- [ ] **Step 3: Rebuild to deploy the global CLAUDE.md**

Run: `just qr`
Expected: rebuild succeeds; the activation step copies `config/CLAUDE.md` to `~/.claude/CLAUDE.md`.

- [ ] **Step 4: Verify the global file was deployed**

Run: `grep -c "skill-cache convention" ~/.claude/CLAUDE.md`
Expected: `1`.

- [ ] **Step 5: Commit**

```bash
git add CLAUDE.md modules/apps/cli/claude-code/config/CLAUDE.md
git commit -m "docs(claude-code): trigger skill-cache adoption when authoring query skills"
```

---

## Notes for the executor

- **Justfile-only rule:** all rebuilds/lints go through `just` (`qr`, `fmt`,
  `health`). The single ad-hoc Nix call (bats in Step 3 of Task 1, before the
  recipe exists) is the one-time bootstrap to watch the tests fail; from Step 6
  on, use `just test-skill-cache`.
- **No co-author/AI trailers** in commits (repo + user rule).
- **Branch:** work continues on `feat/skill-cache-convention` (already created).
- **Do not** retrofit aha/todoist/sfdc SKILL.md in this plan — that is follow-on
  adoption work; coordinate the aha edit with the separate in-flight aha effort.

## Self-review (completed)

- **Spec coverage:** contract doc (Task 3) ✓, `skill-cache` CLI with the exact
  surface and exit codes (Task 1) ✓, two-tier + never-cache-live-state (Task 1
  logic + Task 3 doc) ✓, XDG location outside Nix tree (Task 1) ✓, Nix packaging
  via `writeShellApplication` (Task 2) ✓, vendoring for portable skills (Task 3
  doc) ✓, both discoverability triggers (Task 4) ✓, testing incl. TTL expiry /
  aliases / corrupt-file / portability via standalone `bash` invocation (Task 1)
  ✓. The "concurrent puts don't corrupt" case from the spec is covered
  structurally by atomic tempfile+mv; no dedicated test (single-user, hard to
  race deterministically in bats) — documented here as a conscious omission.
- **Placeholder scan:** none — every step has concrete code/commands/expected
  output.
- **Type/name consistency:** `get/put/forget/list/path`, `--ttl/--alias/
  --allow-stale/--json`, exit codes `3`/`4`, `tables`/`value`/`aliases`/
  `cached_at`/`expires_at`, and the `apps.cli.skill-cache.enable` option name are
  used identically across the script, tests, module, and doc.
```
