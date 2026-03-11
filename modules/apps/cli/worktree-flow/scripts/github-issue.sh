# github-issue: AI-powered worktree workflow for GitHub issues
# Full implementation in Phase 2

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: github-issue <issue-number>"
  info "Creates an isolated git worktree and launches Claude to work on a GitHub issue."
  exit 0
fi

if [[ $# -lt 1 ]]; then
  die "usage: github-issue <issue-number>"
fi

info "github-issue: stub command loaded successfully"
info "lib.sh primitives available: info, ok, warn, die, section, write_state, cleanup, assert_not_main, assert_clean_tree, safe_push, unlock_git_crypt, default_branch, create_state, set_phase, read_state_field, register_cleanup, slugify, worktree_base"
ok "foundation validated"
