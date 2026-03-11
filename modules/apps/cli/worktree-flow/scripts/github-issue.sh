# github-issue: AI-powered worktree workflow for GitHub issues
# Phase 2 will implement full workflow; this stub validates the contract

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: github-issue <issue-number>"
  info "Creates an isolated git worktree and launches Claude to work on a GitHub issue."
  exit 0
fi

if [[ $# -lt 1 ]]; then
  die "usage: github-issue <issue-number>"
fi

ISSUE_NUMBER="$1"
info "github-issue: validating foundation for issue #${ISSUE_NUMBER}"

# CL-03: All setup operations before Claude launch
section "Pre-flight checks"
assert_clean_tree
ok "working tree is clean"

DEFAULT=$(default_branch)
ok "default branch: ${DEFAULT}"

# Show worktree path that would be used
WT_BASE=$(worktree_base)
info "worktree base: ${WT_BASE}"

# CL-01: Shell owns lifecycle (demonstrated by phase announcements)
section "Lifecycle phases"
info "Phase: setup        -- create worktree, write state file (CL-02)"
info "Phase: claude_running -- launch claude with SKILL.md prompt (CL-01)"
info "Phase: claude_exited -- check for changes, extract session_id (CL-05)"
info "Phase: pushing       -- safe_push to remote (SF-01)"
info "Phase: pr_created    -- gh pr create with Summary/Test plan body"

# CL-04: SKILL.md is deployed separately via home.file
if [[ -f "${HOME}/.claude/skills/github-issue/SKILL.md" ]]; then
  ok "SKILL.md found at ~/.claude/skills/github-issue/SKILL.md"
else
  warn "SKILL.md not found -- rebuild may be needed"
fi

ok "foundation validated for github-issue"
info "(stub: no worktree created, no Claude launched -- Phase 2 implements full workflow)"
