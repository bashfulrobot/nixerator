# hack: AI-powered worktree workflow for quick tasks
# Full implementation in Phase 3

if [[ "${1:-}" == "--help" ]] || [[ "${1:-}" == "-h" ]]; then
  info "Usage: hack \"<description>\""
  info "Creates an isolated git worktree and launches Claude for a quick task."
  exit 0
fi

if [[ $# -lt 1 ]]; then
  die "usage: hack \"<description>\""
fi

info "hack: stub command loaded successfully"
info "lib.sh primitives available: info, ok, warn, die, section, write_state, cleanup, assert_not_main, assert_clean_tree, safe_push, unlock_git_crypt, default_branch, create_state, set_phase, read_state_field, register_cleanup, slugify, worktree_base"
ok "foundation validated"
