# Phase 3: hack Workflow - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Full `hack "<description>"` command that creates a worktree at `../.worktrees/hack-<slug>/`, launches Claude to implement, presents an interactive diff review via `gum pager`, merges locally on approval (fast-forward only), and cleans up. Replaces the current stub with a complete end-to-end workflow.

</domain>

<decisions>
## Implementation Decisions

### Reject behavior
- On reject: always preserve the worktree, never offer to delete
- Print the worktree path and a resume hint: "Run `hack \"<description>\"` again to review"
- No re-launch prompt on reject; user decides when to come back

### Resume and re-invocation
- Match existing worktrees by slug: `hack "add rate limiting"` finds `hack-add-rate-limiting` worktree
- Same pattern as github-issue: show state summary, gum choose Resume/Remove/Abort
- On resume from diff_review phase: always show the diff again before approve/reject (user may have forgotten)

### Approve and cleanup
- After approval: auto-delete worktree silently (no confirmation prompt)
- Delete the hack branch after successful merge (clean slate, matches github-issue cleanup)
- Fast-forward merge only; no force merge or rebase

### Claude prompt
- Pass SKILL.md (commit conventions) + description string in the `-p` prompt
- Same SKILL.md as github-issue (consistent commit style across both commands)
- Let Claude discover CLAUDE.md naturally (it reads it automatically)
- Single argument only: the description string. No --file or extra flags

### Claude's Discretion
- Merge failure handling (what to do when fast-forward fails)
- Diff presentation details (coloring, format passed to gum pager)
- Exact prompt wording and structure

</decisions>

<specifics>
## Specific Ideas

- Resume hint on reject should be a copy-pasteable command, not just a path
- Branch naming follows WT-01: `hack/<slug>` (already established in requirements)
- Worktree path: `$(worktree_base)/hack-${SLUG}` (already in the stub)
- Phase progression: setup, claude_running, claude_exited, diff_review, merged, cleanup_done

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib.sh`: all shared primitives (info/ok/warn/die, section, slugify, write_state, set_phase, read_state_field, register_cleanup, assert_clean_tree, default_branch, unlock_git_crypt, worktree_base, check_orphan_worktrees)
- `github-issue.sh`: full reference implementation for worktree lifecycle, Claude launch, resume/re-invocation, orphan detection
- `default.nix`: hack-cmd already scaffolded with writeShellApplication and runtimeInputs (missing llm-agents.claude-code, needs adding)

### Established Patterns
- Phase functions: `phase_setup()`, `phase_claude_running()`, `phase_claude_exited()` etc.
- `handle_existing_worktree()`: state summary + gum choose Resume/Remove/Abort
- `phase_resume()`: numeric start index for sequential phase execution
- `_WT_CLEANUP_PATH=""` before intentional worktree operations (prevents EXIT trap double-remove)
- Claude launch in subshell with `unset CLAUDECODE` to prevent nested session refusal

### Integration Points
- `hack.sh` replaces current stub in `modules/apps/cli/worktree-flow/scripts/`
- State file type: "hack" (vs "issue" for github-issue)
- State file includes `description` field (vs `issue_number`/`issue_title`/`issue_body` for github-issue)
- `default.nix` needs `llm-agents.claude-code` added to hack-cmd runtimeInputs

</code_context>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

*Phase: 03-hack-workflow*
*Context gathered: 2026-03-11*
