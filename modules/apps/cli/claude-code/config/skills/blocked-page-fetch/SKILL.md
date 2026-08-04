---
name: blocked-page-fetch
description: >-
  Fetch a web page when WebFetch fails, 403s, or hits a Cloudflare/JS
  challenge or login wall (common on Reddit and similar bot-gated sites), by
  delegating to a second agent (`agy`, the Antigravity/Gemini CLI) that has
  its own browsing capability. Use only after WebFetch has already failed for
  the URL, never as a first choice.
allowed-tools: ["Bash", "WebFetch"]
---

# Second-agent fetch fallback

WebFetch can't reach every page: Reddit's login wall, Cloudflare-challenged
sites, and anything else that blocks non-browser fetchers. `agy` (the
Antigravity CLI, Gemini-backed, with its own browsing) can often get through
where WebFetch can't.

## When to use this

1. Try `WebFetch` first, always.
2. Only fall back to `agy` when `WebFetch` errors, returns a 403, or lands on
   a Cloudflare/JS-challenge or login-wall page.

## How

```bash
agy --dangerously-skip-permissions --print-timeout 120s --print \
  "Fetch the full content at <URL> and return it verbatim as markdown. Do not summarize or omit sections." \
  < /dev/null
```

- `agy` ignores stdin once a prompt arrives via `--print` — always redirect
  `< /dev/null` (same pattern as `apps/cli/gcmt/scripts/gcmt.sh`).
- `--print-timeout 120s` avoids hanging on slow-loading pages.
- Ask for verbatim content, not a summary — summarizing the result is your
  job, not the second agent's.
- Requires `GEMINI_API_KEY` (exported in `apps/cli/fish`) and `agy`'s own OS
  keychain auth. If either is missing this will fail; tell the user the page
  couldn't be fetched rather than guessing at its contents.
- First use may prompt for `Bash(agy *)` approval — expected, not a bug.

Not for Kong docs — use `kong-docs-lookup` for those.
