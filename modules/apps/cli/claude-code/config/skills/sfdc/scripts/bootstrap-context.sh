#!/usr/bin/env bash
# Idempotent bootstrap for the sfdc skill's context folder.
#
# Creates (if missing):
#   $SFDC_CONTEXT_DIR/
#     .graymatter/        GrayMatter database (agent ID: sfdc)
#     .mcp.json           Claude Code MCP wiring for graymatter
#     CLAUDE.md           Instructions for any Claude session in this folder
#
# Default SFDC_CONTEXT_DIR is $HOME/sfdc. Override by exporting the env var.

set -euo pipefail

CTX_DIR="${SFDC_CONTEXT_DIR:-$HOME/sfdc}"
GM_DIR="$CTX_DIR/.graymatter"

if [[ -f "$GM_DIR/gray.db" && -f "$CTX_DIR/CLAUDE.md" && -f "$CTX_DIR/.mcp.json" ]]; then
  echo "sfdc context already initialized at: $CTX_DIR" >&2
  exit 0
fi

if ! command -v graymatter >/dev/null 2>&1; then
  echo "ERROR: graymatter CLI not found in PATH." >&2
  echo "Install graymatter first, then rerun this script." >&2
  exit 1
fi

mkdir -p "$CTX_DIR"

# graymatter init creates .graymatter/ and wires .mcp.json for Claude Code.
# Run it from inside the context dir so relative paths resolve correctly.
(
  cd "$CTX_DIR"
  # --only claudecode: don't touch cursor/codex/opencode configs we don't use here.
  graymatter init --only claudecode --quiet
)

# CLAUDE.md -- directs any Claude session started in this folder to use
# graymatter for persistent memory. The sfdc skill itself works from any
# CWD and does not require MCP to be active; this file is here for when
# the user cd's into $CTX_DIR for extended SFDC work.
if [[ ! -f "$CTX_DIR/CLAUDE.md" ]]; then
  cat >"$CTX_DIR/CLAUDE.md" <<'EOF'
# SFDC Workspace

This folder is the context/memory home for the `sfdc` Claude skill
(Salesforce CLI operations).

## Memory

Use the `graymatter` MCP server (wired in `.mcp.json`) for persistent
memory. Agent ID: `sfdc`.

- `memory_search` with `agent_id: "sfdc"` -- recall prior context before
  acting
- `memory_add` with `agent_id: "sfdc"` -- store reusable knowledge after
  acting

What's worth remembering:
- Field API names on custom SObjects (especially `__c` fields)
- SOQL patterns that produced the right answer
- Record IDs the user has referenced by name (e.g. "our Acme account")
- Org-specific gotchas: required fields, validation rules, read-only
  formula fields, triggers that fire on write

What's NOT worth remembering: raw query outputs, transient task state,
things the user can rediscover trivially.

## Salesforce operations

The `sfdc` skill (invoke explicitly with `/sfdc` or by asking about
Salesforce/SFDC/SOQL/`sf` commands) provides the full workflow, SOQL
cheatsheet, `sf` command reference, and the writes playbook.

Default posture is read-only. Every destructive operation goes through the
writes playbook (describe -> select -> plan -> explicit confirmation ->
canary -> execute -> verify). No exceptions.

## Case creation is elsewhere

To create a Salesforce Support Case, use the `log-support-ticket` skill,
not the `sfdc` skill. `log-support-ticket` handles the full workflow
including Slack thread extraction, account/contact lookup, and
product-type picking.
EOF
fi

echo "sfdc context initialized at: $CTX_DIR" >&2
echo "  database: $GM_DIR/gray.db" >&2
echo "  mcp:      $CTX_DIR/.mcp.json" >&2
echo "  claude:   $CTX_DIR/CLAUDE.md" >&2
