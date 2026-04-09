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

### Use of tools

- **Research-First, never Edit-First** — understand context before touching code to ensure you use the most appropriate tool. Prefer surgical edits over rewrites.
- Use **Reasoning Loops** frequently. Don't skip them.

### Thinking Depth

- Always apply the highest level of thinking depth. Spending more tokens for better output is fine.
- Never reason from assumptions — read and understand actual code, publications, and documentation before deciding.
