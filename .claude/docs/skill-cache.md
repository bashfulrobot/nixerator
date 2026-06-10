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

## Concurrency

Each `put`/`forget` rewrites the whole per-skill file atomically (tempfile +
rename — no torn file). Writes are **not** serialized against each other, so two
processes writing the same `<skill>` concurrently can clobber one another. Call
the CLI sequentially per skill — the normal case for a skill resolving
identifiers one at a time. Do not fan out parallel `put`s to the same `<skill>`.

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
