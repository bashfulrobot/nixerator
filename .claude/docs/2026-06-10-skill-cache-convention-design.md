# skill-cache: a warm-cache convention for query skills — design

A reusable convention (documented contract + Nix-packaged CLI + per-skill cache
files) that lets query-style skills cache the identifiers and slow-changing
metadata they otherwise re-resolve on every run. First adopters: aha, todoist,
sfdc. Designed to work both for internal skills (managed in nixerator) and for
portable skills published to a corporate marketplace for teammates.

## Problem

Query skills re-derive the same facts every invocation. The aha skill looks up a
customer's idea-portal id and reference prefix; the todoist skill resolves a
project name to its id; sfdc resolves an account name to an Account Id. These are
API round-trips for data that almost never changes, repeated every session.

The aha skill already references Claude Code's **native auto-memory** for this
(SKILL.md "Memory" section), but native auto-memory is keyed **per project
directory** (`~/.claude/projects/<encoded-cwd>/memory/`). A CSM customer lookup
is cross-project: resolved in one repo today, it is absent from a different
repo's store tomorrow. The per-directory store is the wrong shape for a
cross-project "book of business", which is why it does not behave like a real
warm cache.

## Goals

- One reusable caching convention every query skill can adopt incrementally.
- Cache two tiers of data:
  - **Identity mappings** — name→id/reference lookups that effectively never
    change. Cached permanently; invalidated only on explicit miss or `forget`.
  - **Slow-changing metadata** — attributes that change rarely (CSM owner,
    segment, custom-field keys). Cached with a TTL and an explicit refresh path.
- **Never** cache live/volatile state (workflow status, endorsement counts, task
  due dates, case status). Always fetch those fresh.
- Survive `just qr` — the cache must live outside the Nix-managed skill tree.
- Work for portable skills on a teammate's machine that has neither the
  nixerator repo nor the packaged CLI.

## Non-goals

- Retrofitting aha/todoist/sfdc SKILL.md files is **not** in this spec — those
  are documented as a follow-on adoption recipe. (aha is being worked
  separately; coordinate the edit there.)
- No caching of live state, no general-purpose response cache, no cross-machine
  cache sync.

## Architecture

Three artifacts, split by ownership:

| Layer | What | Lives in | Managed by |
|-------|------|----------|------------|
| Contract | `skill-cache.md` — file-format spec, tier rules, TTL semantics, adoption recipe, when-to-adopt checklist | `.claude/docs/skill-cache.md` (repo) | Git / PR review |
| Tool | `skill-cache` CLI — atomic read/write, TTL, key normalization | Nix `writeShellApplication` in the claude-code module, wrapping the canonical script | Nix (declarative, on PATH) |
| Data | per-skill cache files | `${XDG_CACHE_HOME:-$HOME/.cache}/claude-skills/<skill>.json` | mutable runtime state, **never** Nix-tracked |

The tool is declarative and global; the data is throwaway and reconstructible
from the API; the doc is the source of truth so the contract can be implemented
even where the CLI is absent.

### Two deployment modes, one script body

The canonical script body lives **once** in the claude-code module. It is
consumed two ways:

| | Internal skills (in nixerator) | Marketplace / portable skills |
|---|---|---|
| Cache logic | Nix-packaged `skill-cache` CLI on PATH | **Vendored** `scripts/skill-cache.sh` copied into the skill |
| Runtime contract | embedded block in SKILL.md | embedded block in SKILL.md (travels with the skill) |
| Dependencies | bash + jq (via Nix) | bash + jq + coreutils only — same as the existing `aha.sh` |
| Author-facing doc | `.claude/docs/skill-cache.md` | not needed at runtime; SKILL.md is self-describing |

Portable mode mirrors the existing aha precedent: `aha.sh` is bundled inside the
skill, depends on no particular tooling, and is "portable and safe to share".
Marketplace skills **vendor a copy** of the canonical script at author time
(decision: vendor-copy, not a shared installable, not PATH-with-fallback). Drift
is managed by re-copying from the canonical source; the script is small, stable,
and dependency-free, so a copy is acceptable — the same way a small vendored
library is.

## The `skill-cache` CLI

```
skill-cache get    <skill> <table> <key> [--allow-stale]
skill-cache put    <skill> <table> <key> <json-value> [--ttl 7d] [--alias NAME]...
skill-cache forget <skill> <table> [<key>]
skill-cache list   <skill> [<table>] [--json]
skill-cache path   <skill>
```

- **`get`** — exit 0 + value JSON on a fresh hit; exit 3 on miss; exit 4 on
  expired. With `--allow-stale`, an expired entry exits 0 and prints the value.
  The non-zero exit is the skill's signal to call the API.
- **`put`** — upsert. **No `--ttl` ⇒ identity tier (never expires).**
  `--ttl 7d` / `30d` / `12h` ⇒ metadata tier; `expires_at` computed at write
  time. `--alias NAME` (repeatable) registers extra lookup keys for one entry.
- **`forget`** — delete a key, or a whole table when `<key>` is omitted. This
  **is** the refresh action: forget, and the next `get` misses so the skill
  re-resolves. The CLI cannot call the API itself, so there is no separate
  `refresh` verb — "refresh" = `forget` + re-fetch by the skill, documented as
  such.
- **`list`** — inspect cached entries (debugging / "what do I have cached").
- **`path`** — print the resolved cache-file path for the skill.

### Implementation notes

- All JSON manipulation via `jq`.
- Writes are atomic (tempfile + `mv` in the same dir) so a crash can't leave a
  torn file. This guards file integrity, not update serialization: concurrent
  writers to one `<skill>` can clobber each other, so the convention assumes
  sequential per-skill writes (see the Concurrency note in the contract doc).
- The cache directory is created on demand (`mkdir -p`).
- Cache path is computed as `${XDG_CACHE_HOME:-$HOME/.cache}/claude-skills/<skill>.json`,
  so it works unchanged on a teammate's Linux/macOS box.
- A missing/corrupt cache file is treated as empty (miss), never a hard error —
  the cache is an optimization, never a correctness dependency.

### Key normalization

`get`, `put`, and `--alias` keys are normalized: lowercase, trim, collapse
internal whitespace to a single space. `get` checks the normalized direct key,
then an alias index. So "Acme", "ACME", and "acme corp" resolve to one entry.

## Cache file schema

One file per skill. `schema` is a version integer for future migrations.

```json
{
  "schema": 1,
  "tables": {
    "customers": {
      "acme-corp": {
        "value": { "portal_id": "PROD", "ref_prefix": "DEVP", "field_keys": {} },
        "aliases": ["acme", "acme corporation"],
        "cached_at": "2026-06-10T16:00:00Z",
        "expires_at": null
      }
    }
  }
}
```

- `tables` — logical record types per skill (`customers`, `projects`,
  `accounts`).
- `value` — arbitrary skill-defined JSON.
- `expires_at: null` ⇒ identity tier (permanent). ISO-8601 timestamp ⇒ metadata
  tier; `get` compares against the current time.
- Timestamps are ISO-8601 UTC.

## The contract each adopting skill embeds

A short block in the skill's SKILL.md, replacing/augmenting any "Memory"
section. Portable skills carry this block verbatim so the skill is
self-describing on a teammate's machine:

> **Before** resolving a `<thing>` → `<id>`, run
> `skill-cache get <skill> <table> <key>` (or `bash scripts/skill-cache.sh …` in
> a vendored skill). On a hit, use the cached value — **no API call**. On
> miss/expired, resolve via the API, then `skill-cache put …` the result. Cache
> **only** stable identity (no `--ttl`) and slow metadata (`--ttl`). **NEVER**
> cache live state — status, counts, due dates, case state. If the user says the
> cache is wrong or stale, `skill-cache forget` the key and re-resolve.

## Discoverability — making future skills consider the cache

Two distinct triggers, because skills are authored both inside and outside
nixerator.

1. **Using a cache-bearing skill (nixerator-local).** A reference TOC entry in
   the project `CLAUDE.md` pointing at `.claude/docs/skill-cache.md`.

2. **Authoring a query skill anywhere on the machine.** The authoring trigger
   lives in the **global** `CLAUDE.md`
   (`modules/apps/cli/claude-code/config/CLAUDE.md`, deployed to
   `~/.claude/CLAUDE.md`, loaded in every project), with an **absolute** path to
   the doc, because skills are sometimes built outside nixerator (e.g. portable
   skills for the corporate marketplace). Proposed wording:

   > When creating or modifying a skill that resolves names→IDs or repeatedly
   > queries an external API, read
   > `/home/dustin/git/nixerator/.claude/docs/skill-cache.md` and consider
   > adopting the `skill-cache` convention (vendor `scripts/skill-cache.sh` for
   > portable/marketplace skills).

   The trigger is keyed to the **shape of the skill** ("resolves names→IDs",
   "repeatedly queries an external API"), so Claude self-selects rather than
   needing to already know the cache exists.

We do **not** edit the upstream `skill-creator` / `writing-skills` plugin skills
— they are not repo-owned and would revert on plugin updates. The CLAUDE.md TOC
entries cover the authoring path reliably.

### Two reinforcing touches in the doc

- The doc opens with a **when-to-adopt / when-NOT-to checklist** (adopt: stable
  name→ID lookups, slow metadata; skip: one-shot skills, write-only skills,
  live-state-only skills) so the decision is mechanical once the trigger fires.
- A worked **"add a table to skill-cache" recipe** so adopting is copy-paste,
  not design-from-scratch — low friction means it actually gets used.

## Worked adoption examples (documented, not retrofitted in this spec)

- **aha** → table `customers`: identity = name→portal id, ref prefix,
  custom-field API keys; metadata (TTL ~30d) = CSM owner, segment. Coordinate
  the SKILL.md edit with the in-flight aha work.
- **todoist** → table `projects`: identity = name→project id, section ids,
  label ids.
- **sfdc** → table `accounts`: identity = name→Account Id; metadata (TTL) =
  owner, region.

## Deliverables

1. `.claude/docs/skill-cache.md` — the contract: schema, location, tiers, TTL
   semantics, CLI reference, embedded-block template, when-to-adopt checklist,
   "add a table" recipe, and the vendoring instructions for portable skills.
2. The canonical `skill-cache` script — authored once in the claude-code module,
   packaged as a `writeShellApplication` (PATH CLI) and used as the copy-source
   for vendoring.
3. Two `CLAUDE.md` TOC entries — a reference entry (project `CLAUDE.md`) and an
   authoring trigger (global `CLAUDE.md`) with the absolute doc path.

## Open items for the implementation plan to verify

- The exact `writeShellApplication` + `home.packages` pattern this repo uses,
  and where the canonical script file should live so it is both packageable and
  copyable for vendoring (a non-skill module path so it is not mis-deployed as a
  skill).
- How the canonical script is exposed for vendoring (a documented absolute path
  to copy from).
- jq version available on PATH (for any jq-version-sensitive syntax).

## Testing

- **CLI unit behaviour** (bats or a shell test): `put` then `get` round-trip;
  identity entry never expires; metadata entry past TTL returns exit 4;
  `--allow-stale` returns exit 0 with stale value; `forget` removes a key and
  the table; alias and case-insensitive lookups hit one entry; missing/corrupt
  file is treated as a miss, not an error; a write leaves no torn file (atomic
  tempfile + rename); concurrent writers are out of scope (single-writer
  assumption).
- **Portability check:** the vendored `scripts/skill-cache.sh` runs with only
  bash + jq + coreutils — no PATH dependency on the packaged CLI.
- **Adoption smoke test:** follow the "add a table" recipe end-to-end for one
  table and confirm a cold lookup populates the cache and a warm lookup skips
  the API.
