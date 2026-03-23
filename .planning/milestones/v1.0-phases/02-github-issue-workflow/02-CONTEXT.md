# Phase 2: github-issue Workflow - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Complete `github-issue <number>` command that creates a worktree, launches Claude, pushes the branch, creates a PR on GitHub, comments on the issue, and cleans up after merge on re-invocation. Replaces the current stub with a full end-to-end workflow.

</domain>

<decisions>
## Implementation Decisions

### Branch Naming

- Type derived from GitHub issue labels via `gh` API: map common labels to gcmt types (bug->fix, enhancement->feat, documentation->docs, etc.)
- Supported branch types (matching gcmt): feat, fix, docs, refactor, test, ci, chore, revert, deps
- Fallback when no label matches: prompt user with `gum choose` from the 9 types
- Slug format: `<type>/<number>-<short-title>` (e.g., `feat/42-rate-limiting`), title slugified and truncated to ~50 chars total

### Resume and Re-invocation

- When worktree already exists: show compact one-liner state summary (e.g., "Issue #42: phase claude_exited, branch feat/42-rate-limiting"), then `gum choose`: Resume / Remove & restart / Abort
- Resume skips to next incomplete phase (idempotent phase progression)
- Claude resume: try `--resume <session_id>` from state file first, fall back to fresh session if unavailable/expired
- State display is compact, not verbose dump

### PR Creation

- PR title: use GitHub issue title as-is
- PR status: created as ready for review (not draft)
- PR body: uses SKILL.md Summary/Test plan template format
- After PR creation: auto-comment on the issue with PR link via `gh issue comment` (RF-02)

### Post-merge Cleanup

- Merge detection: query PR state via `gh pr view --json state` using pr_url from state file
- Cleanup shows each step with ok/info messages (matches existing terminal style)
- Resolution comment on issue/PR: short one-liner (e.g., "Resolved via #<pr-number>. Branch and worktree cleaned up.")
- Idempotent cleanup: skip missing pieces (e.g., worktree already deleted), still clean branches and post comments

### Claude's Discretion

- Label-to-type mapping details (which labels map to which types beyond the obvious ones)
- Exact `gh api` queries for issue metadata and PR state
- How to extract/format the Summary/Test plan body from Claude's commits
- Orphan worktree detection implementation (WT-02)

</decisions>

<specifics>
## Specific Ideas

- Branch types should match gcmt's supported types exactly (user's curated list of 9, not all 13)
- Phase progression is linear and idempotent: each phase checks its own preconditions and skips if already done
- The SKILL.md already deployed by Phase 1 defines commit conventions and PR body format; the script should leverage that contract

</specifics>

<code_context>

## Existing Code Insights

### Reusable Assets

- `lib.sh`: info/ok/warn/die color helpers, section(), assert_clean_tree(), assert_not_main(), safe_push(), default_branch(), worktree_base(), slugify(), create_state(), set_phase(), read_state_field(), register_cleanup(), unlock_git_crypt()
- `default.nix`: writeShellApplication with runtimeInputs (git, git-crypt, gum, gh, jq, coreutils, gnused, findutils)
- SKILL.md at `~/.claude/skills/github-issue/SKILL.md` with commit conventions + PR body format

### Established Patterns

- State file: `.worktree-state.json` at worktree root with atomic writes (tmpfile + mv)
- Phase tracking: linear phases (setup, claude_running, claude_exited, pushing, pr_created, merged, cleanup_done)
- `gum confirm` always wrapped in `if` for set -e safety (SF-04)
- Claude launch: `--dangerously-skip-permissions`, `-p` with prompt, `--output-format stream-json`

### Integration Points

- `github-issue.sh` replaces current stub in `modules/apps/cli/worktree-flow/scripts/`
- Worktree created at `$(worktree_base)/issue-<number>/`
- gh CLI for issue metadata, PR creation, issue comments, PR state queries
- Session ID extracted from stream-json output for --resume support

</code_context>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

_Phase: 02-github-issue-workflow_
_Context gathered: 2026-03-11_
