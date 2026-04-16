# Global Instructions

## File Sharing

When asked to send a file to my phone, use:

```
sudo tailscale file cp /PATH/TO/FILE.EXT maximus:
```

## Claude Code Behaviour Guidelines

- **Own every problem** — never deflect with "not my changes", "pre-existing issue", "known limitation", or defer to "future work". Diagnose and fix it.
- **Don't stop early** — no "good stopping point" or "natural checkpoint". Push through to a complete solution.
- **Don't ask permission to continue** — if you have the knowledge and capability to solve a problem, just act. No "should I continue?" or "want me to keep going?".
- Plan multi-step approaches before acting (which files, which order, which tools).
- Recall and apply project-specific conventions from CLAUDE.md files.
- Self-check with reasoning loops; fix mistakes before committing or asking for help.

### Git Attribution

- Never add Co-Authored-By, Signed-off-by, or any AI attribution trailer to commits.
- No mentions of Claude, Anthropic, AI, or "generated" in commit messages, PR bodies, or issue comments.
- The user's git identity is the sole author.

### Use of tools

- **Research-First, never Edit-First** — understand context before touching code to ensure you use the most appropriate tool. Prefer surgical edits over rewrites.
- Use **Reasoning Loops** frequently. Don't skip them.

### Thinking Depth

- Always apply the highest level of thinking depth. Spending more tokens for better output is fine.
- Never reason from assumptions — read and understand actual code, publications, and documentation before deciding.

## Kong Developer Documentation

Kong's developer docs at `developer.konghq.com` are available in LLM-friendly markdown. To get the markdown version of any content page, append `.md` to the URL path (drop trailing slashes and anchors):

- `https://developer.konghq.com/dev-portal/` → `https://developer.konghq.com/dev-portal.md`
- `https://developer.konghq.com/konnect-platform/teams-and-roles/#predefined-teams` → `https://developer.konghq.com/konnect-platform/teams-and-roles.md`
- `https://developer.konghq.com/observability/` → `https://developer.konghq.com/observability.md`

**Index/site-tree pages do NOT have markdown versions** (e.g., `https://developer.konghq.com/` or `https://developer.konghq.com/index/dev-portal/`).

When researching Kong topics, always prefer fetching the `.md` URL — it is optimized for AI consumption and avoids noisy HTML parsing.
