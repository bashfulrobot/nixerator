# hack: AI-powered worktree workflow for quick tasks
# Phase 3 will implement full workflow; this stub validates the contract

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: hack \"<description>\""
  info "Creates an isolated git worktree and launches Claude for a quick task."
  exit 0
fi

if [[ $# -lt 1 ]]; then
  die "usage: hack \"<description>\""
fi

DESCRIPTION="$1"
SLUG=$(slugify "$DESCRIPTION")
info "hack: validating foundation for task '${DESCRIPTION}'"
info "generated slug: ${SLUG}"

# CL-03: All setup operations before Claude launch
section "Pre-flight checks"
assert_clean_tree
ok "working tree is clean"

DEFAULT=$(default_branch)
ok "default branch: ${DEFAULT}"

# Show worktree path that would be used
WT_BASE=$(worktree_base)
info "worktree base: ${WT_BASE}"
info "worktree would be: ${WT_BASE}/hack-${SLUG}"

# CL-01: Shell owns lifecycle
section "Lifecycle phases"
info "Phase: setup        -- create worktree, write state file (CL-02)"
info "Phase: claude_running -- launch claude with SKILL.md prompt (CL-01)"
info "Phase: claude_exited -- check for changes, extract session_id (CL-05)"
info "Phase: diff_review   -- gum pager diff review"
info "Phase: merged/cleanup -- local merge or abandon"

# CL-04: SKILL.md is deployed separately via home.file
if [[ -f "${HOME}/.claude/skills/github-issue/SKILL.md" ]]; then
  ok "SKILL.md found at ~/.claude/skills/github-issue/SKILL.md"
else
  warn "SKILL.md not found -- rebuild may be needed"
fi

ok "foundation validated for hack"
info "(stub: no worktree created, no Claude launched -- Phase 3 implements full workflow)"
