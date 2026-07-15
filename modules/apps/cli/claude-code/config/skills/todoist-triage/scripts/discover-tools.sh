#!/usr/bin/env bash
# discover-tools.sh — audit the data sources actually installed on this machine,
# so references/data-sources.md can be kept honest. Prints two lists:
#   1. skills under ~/.claude/skills/ (name + first line of description)
#   2. a reminder of which MCP servers to confirm in-session
#
# This does NOT edit the registry — it reports. After running, reconcile
# references/data-sources.md by hand (mark installed vs GAP). MCP servers can
# only be enumerated from inside a Claude session (via ToolSearch), not from a
# shell, so those are listed as a checklist.
#
# Usage: discover-tools.sh
set -euo pipefail

SKILLS_DIR="${HOME}/.claude/skills"

echo "== Installed skills ($SKILLS_DIR) =="
if [ -d "$SKILLS_DIR" ]; then
  for d in "$SKILLS_DIR"/*/; do
    name=$(basename "$d")
    desc=$(sed -n 's/^description:[[:space:]]*//p' "$d/SKILL.md" 2>/dev/null | head -n1 | cut -c1-100)
    printf '  %-24s %s\n' "$name" "$desc"
  done
else
  echo "  (no skills dir)"
fi

cat <<'EOF'

== MCP servers to confirm in-session ==
(Enumerate live with ToolSearch; mark each present/absent in data-sources.md.)
  - Slack (read)         plugin_slack_slack__*        — channel/thread/user reads
  - Atlassian            plugin_atlassian_atlassian__* — Jira / Confluence
  - Tableau              tableau__*                    — health / renewal / usage
  - Gmail / Calendar     claude_ai_Gmail__*, ...       — prefer `gws` for Kong mail
  - Todoist (MCP)        claude_ai_Todoist__*          — prefer `td` (todoist-cli)

Registry to reconcile:  references/data-sources.md
EOF
