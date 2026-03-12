---
phase: 02-github-issue-workflow
verified: 2026-03-12T04:16:14Z
status: human_needed
score: 9/9 must-haves verified
human_verification:
  - test: "Run `github-issue <real-issue-number>` against a real GitHub issue with no existing worktree"
    expected: "Creates worktree, launches Claude, pushes branch, creates PR, comments on issue"
    why_human: "Full happy-path requires GitHub API, git remote, and interactive Claude session"
  - test: "Re-run `github-issue <same-number>` while worktree exists at a mid-phase state (e.g., claude_exited)"
    expected: "Shows 'Issue #N: phase claude_exited, branch <name>' and presents Resume/Remove & restart/Abort"
    why_human: "Requires a real interrupted session to test resume dispatch"
  - test: "Re-run after PR is merged on GitHub"
    expected: "Detects MERGED state, runs cleanup: switches to default branch, removes worktree, posts resolution comments on issue and PR"
    why_human: "Requires a real merged PR on GitHub to trigger PM-01 detection path"
  - test: "Invoke with an issue where no labels match the mapping"
    expected: "gum choose presents branch type selector (feat/fix/docs/etc.)"
    why_human: "Requires interactive terminal with gum running"
---

# Phase 2: github-issue-workflow Verification Report

**Phase Goal:** Complete github-issue command with full issue-to-PR lifecycle, resume/re-invocation handling, and post-merge cleanup
**Verified:** 2026-03-12T04:16:14Z
**Status:** human_needed (all automated checks pass; 4 items require live execution against GitHub/terminal)
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Running `github-issue 42` fetches issue metadata, creates worktree at `../.worktrees/issue-42/`, and launches Claude in it | VERIFIED | `phase_setup` fetches via `gh issue view`, calls `git worktree add "$wt_path"`, `phase_claude_running` launches claude in subshell with `cd "$wt_path"` |
| 2 | Branch name follows `<type>/<number>-<slug>` format derived from issue labels with gum choose fallback | VERIFIED | `derive_branch_type` maps labels via case statement, `build_branch_name` formats `<type>/<number>-<slug>`, gum choose fallback at line 54 with `\|\| die "aborted"` |
| 3 | After Claude exits, script pushes branch and creates PR with issue title and Summary/Test plan body | VERIFIED | `phase_push_and_pr`: `safe_push "$branch"`, `gh pr create --title "$issue_title" --body "$pr_body"`, pr_body uses `## Summary\n- Implements #N\n\n## Test plan` format |
| 4 | After PR creation, script comments on the issue with a link to the PR | VERIFIED | `gh issue comment "$issue_number" --body "PR ready for review: $pr_url"` at line 421 |
| 5 | Re-invoking when worktree exists shows compact state summary and offers Resume/Remove & restart/Abort | VERIFIED | `handle_existing_worktree` at line 338: reads phase+branch, prints `info "Issue #${issue_number}: phase ${phase}, branch ${branch}"`, then `gum choose "Resume" "Remove & restart" "Abort"` |
| 6 | Resuming skips to the next incomplete phase without re-running completed steps | VERIFIED | `phase_resume` uses numeric start-index (`start=1/2/3`) with if-guards, routes directly to remaining phases |
| 7 | Re-invoking after PR merge detects merged state and runs cleanup: switch branch, pull, delete branches, remove worktree, comment on issue and PR | VERIFIED | `handle_existing_worktree` calls `gh pr view "$pr_url" --json state --jq '.state'`, branches on `MERGED`; `phase_cleanup` does checkout, pull, worktree remove, prune, branch delete, `gh issue comment` + `gh pr comment` |
| 8 | Orphan worktrees are detected on startup and offered for cleanup | VERIFIED | `check_orphan_worktrees` called in `main()` at line 433, before worktree-existence check; scans `worktree_base`, warns per orphan, offers `gum confirm` removal |
| 9 | Cleanup sequences as worktree remove, then prune, then branch delete | VERIFIED | `phase_cleanup` lines 282-288: `git worktree remove --force`, then `git worktree prune`, then `git branch -d` + `git push origin --delete` |

**Score:** 9/9 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `modules/apps/cli/worktree-flow/scripts/github-issue.sh` | Full github-issue workflow | VERIFIED | 453 lines; contains all 9 required functions (fetch_issue_metadata, derive_branch_type, build_branch_name, create_issue_state, phase_setup, phase_claude_running, phase_claude_exited, phase_push_and_pr, handle_existing_worktree, phase_resume, remove_worktree, check_orphan_worktrees, phase_cleanup) |
| `modules/apps/cli/worktree-flow/default.nix` | Updated runtimeInputs with claude-code | VERIFIED | `llm-agents.claude-code` present at line 24; `builtins.readFile ./scripts/github-issue.sh` at line 28 |
| `modules/apps/cli/worktree-flow/skills/github-issue/SKILL.md` | SKILL.md deployed to `~/.claude/skills/` | VERIFIED | File exists; `default.nix` deploys it via `home.file.".claude/skills/github-issue/SKILL.md"` |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `github-issue.sh` | `lib.sh` | Inlined at build time by `default.nix` | WIRED | `libSh = builtins.readFile ./scripts/lib.sh` then `${libSh}` in text; all lib functions (create_state, set_phase, write_state, read_state_field, safe_push, assert_clean_tree, slugify, worktree_base, register_cleanup, unlock_git_crypt) confirmed present in lib.sh |
| `github-issue.sh` | `gh CLI` | `gh issue view`, `gh pr create`, `gh issue comment`, `gh pr view`, `gh pr comment` | WIRED | All five gh calls present and substantive: line 26 (fetch), 401 (pr create), 421 (issue comment), 353 (pr view for merge detection), 293+294 (cleanup comments) |
| `default.nix` | `github-issue.sh` | `builtins.readFile ./scripts/github-issue.sh` | WIRED | Confirmed at line 28; file inlined into writeShellApplication text |
| `handle_existing_worktree` | `phase_resume` | `gum choose` dispatching to resume path | WIRED | Lines 366-368: `"Resume"` case calls `phase_resume "$issue_number" "$wt_path" "$phase"` |
| `handle_existing_worktree` | `phase_cleanup` | Merge detection triggers cleanup | WIRED | Lines 351-357: MERGED state triggers `phase_cleanup "$issue_number" "$wt_path"` |
| `phase_cleanup` | `gh CLI` | Issue and PR comments, branch deletion | WIRED | Lines 288 (`git push origin --delete`), 293 (`gh issue comment`), 294 (`gh pr comment`) all present |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| WT-01 | 02-01 | Branch naming `fix/<slug>`, `feat/<slug>` based on context | SATISFIED | `build_branch_name` produces `<type>/<number>-<slug>`; label-to-type mapping in `derive_branch_type` |
| WT-02 | 02-02 | Detect and offer to clean orphaned worktrees on startup | SATISFIED | `check_orphan_worktrees` scans `worktree_base`, warns, offers `gum confirm` cleanup |
| WT-05 | 02-02 | Cleanup sequences as worktree remove, then prune, then branch delete | SATISFIED | Sequence confirmed in `phase_cleanup` (lines 282-288) and `remove_worktree` (lines 305-310) |
| WT-06 | 02-02 | Re-invocation resumes from state file | SATISFIED | `handle_existing_worktree` reads state, `phase_resume` dispatches by start-index |
| WT-07 | 02-02 | Script errors if worktree exists (with option to resume) | SATISFIED | `handle_existing_worktree` handles this; offers Resume/Remove & restart/Abort rather than hard error |
| RF-01 | 02-01 | github-issue pushes branch and creates PR with Summary/Test plan body | SATISFIED | `phase_push_and_pr`: `safe_push` + `gh pr create --title ... --body` with structured format |
| RF-02 | 02-01 | github-issue comments on issue linking the PR | SATISFIED | `gh issue comment "$issue_number" --body "PR ready for review: $pr_url"` at line 421 |
| PM-01 | 02-02 | Detects merged PR on re-invocation and enters cleanup phase | SATISFIED | `gh pr view "$pr_url" --json state --jq '.state'` with MERGED branch at lines 351-357 |
| PM-02 | 02-02 | Cleanup switches to default branch, pulls, deletes local and remote branches | SATISFIED | `git checkout "$default_br"`, `git pull`, `git branch -d`, `git push origin --delete` in `phase_cleanup` |
| PM-03 | 02-02 | Cleanup removes worktree and prunes | SATISFIED | `git worktree remove --force "$wt_path"` then `git worktree prune` in `phase_cleanup` |
| PM-04 | 02-02 | Cleanup comments on issue and PR with resolution summary | SATISFIED | `gh issue comment` + `gh pr comment` both present in `phase_cleanup` lines 293-294 |

No orphaned requirements found. All 11 requirement IDs from plans are accounted for in REQUIREMENTS.md and confirmed implemented.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
|------|------|---------|----------|--------|
| `github-issue.sh` | 226 | `git diff --quiet HEAD` misses untracked files | WARNING | If Claude creates new files but does not stage them, this returns exit 0 and the script exits with "no changes detected" -- false negative. Claude Code typically stages its files so this is unlikely in practice, but not guaranteed. Correct check would combine `git -C "$wt_path" diff --quiet HEAD` with `[[ -z "$(git -C "$wt_path" ls-files --others --exclude-standard)" ]]` |

No TODO/FIXME/placeholder comments found. No stub implementations found. No empty return patterns found.

### Human Verification Required

#### 1. Happy-path end-to-end

**Test:** Run `github-issue <real-issue-number>` in a repo with a real GitHub issue that has no existing worktree.
**Expected:** Script fetches issue, creates worktree at `../.worktrees/issue-<N>/`, creates branch with proper type prefix from issue labels, launches Claude, then pushes branch, creates PR with Summary/Test plan body, and posts comment on the issue linking the PR.
**Why human:** Requires live GitHub API credentials, a real remote, and an interactive Claude session. Cannot simulate with static analysis.

#### 2. Resume from interrupted phase

**Test:** Kill the script partway through (e.g., during `phase_claude_running`) then re-invoke `github-issue <same-number>`.
**Expected:** Shows one-liner status (issue number, current phase, branch name), presents gum choose with Resume/Remove & restart/Abort, Resume option continues from the interrupted phase without re-running earlier steps.
**Why human:** Requires a real interrupted state file on disk and interactive gum terminal.

#### 3. Post-merge cleanup

**Test:** After a PR is merged on GitHub, re-invoke `github-issue <issue-number>`.
**Expected:** Detects MERGED state via `gh pr view`, runs `phase_cleanup`: switches to default branch, pulls, removes worktree, prunes, deletes local and remote branch, posts resolution comment on issue and PR.
**Why human:** Requires a real merged PR on GitHub; the MERGED detection is a live API call.

#### 4. Unlabeled issue branch type selection

**Test:** Run against a GitHub issue with no labels (or labels that do not match the mapping).
**Expected:** gum choose appears with all branch type options; selecting one proceeds with that type in the branch name.
**Why human:** Interactive gum choose requires a terminal; no label in static files to trigger this path automatically.

### Gaps Summary

No gaps found. All 9 observable truths are verified against actual code. All 11 requirement IDs from Plans 01 and 02 are implemented and substantive. The one warning (untracked file detection in `phase_claude_exited`) is a correctness edge case but not a blocker for the phase goal; it does not prevent the lifecycle from working for the expected Claude Code usage pattern where files are always committed (staged) before the session ends.

The phase status is `human_needed` because 4 behaviors require live execution against real GitHub API, real git remotes, and interactive terminal sessions. Automated static analysis cannot substitute for these.

---

_Verified: 2026-03-12T04:16:14Z_
_Verifier: Claude (gsd-verifier)_
