---
name: kong-docs-lookup
description: >-
  Fetch Kong developer docs as LLM-friendly markdown by appending `.md` to the URL
  path. Use before fetching or citing anything from developer.konghq.com, when
  researching Kong Gateway, Konnect, dev portal, mesh, decK, kongctl, plugins, or
  Kong observability, and when the user pastes a Kong docs link or asks you to
  look something up in the Kong docs.
allowed-tools: ["WebFetch", "WebSearch", "Read"]
---

# Kong Developer Documentation

Kong's developer docs at `developer.konghq.com` are available in LLM-friendly markdown. To get the markdown version of any content page, append `.md` to the URL path (drop trailing slashes and anchors):

- `https://developer.konghq.com/dev-portal/` → `https://developer.konghq.com/dev-portal.md`
- `https://developer.konghq.com/konnect-platform/teams-and-roles/#predefined-teams` → `https://developer.konghq.com/konnect-platform/teams-and-roles.md`
- `https://developer.konghq.com/observability/` → `https://developer.konghq.com/observability.md`

**Index/site-tree pages do NOT have markdown versions** (e.g., `https://developer.konghq.com/` or `https://developer.konghq.com/index/dev-portal/`).

When researching Kong topics, always prefer fetching the `.md` URL — it is optimized for AI consumption and avoids noisy HTML parsing.

## Local alternative

A local RAG index of the Kong docs is also available through the `kong-docs`
MCP server (kongdex). When it is connected, prefer it for broad "where is this
documented" questions and use the `.md` URLs above to read the specific pages
it points at.
