# State Detection

Detect the current lifecycle state on every invocation. This runs before any action — the skill must know where it is before deciding what to do.

## Worktree Audit (pre-flight)

Before routing to a specific issue, scan all existing issue worktrees and cross-reference their PR state. This catches work that's ready for cleanup and gives the user a complete picture.

### Procedure

```bash
# 1. Find the worktree base directory
wt_base="$(git rev-parse --show-toplevel)/../.worktrees"

# 2. Scan all issue worktrees
find "$wt_base" -maxdepth 1 -name 'issue-*' -type d 2>/dev/null

# 3. For each, read .worktree-state.json and check PR state
for wt_dir in "$wt_base"/issue-*; do
  state_file="$wt_dir/.worktree-state.json"
  # Read: issue_number, issue_title, phase, branch, pr_url
  # If pr_url exists: gh pr view <pr_url> --json state,reviewDecision
done
```

### Report Format

Present a table to the user:

```
Active issue worktrees:
  #42: add JWT auth [pr_created] — PR merged ⚠️ ready for cleanup
  #17: fix null response [claude_running] — PR: changes requested
  #53: update docs [pushing] — no PR yet
  #8:  refactor DB layer [pr_created] — PR approved, ready to merge
```

Flag worktrees with merged PRs prominently — these are stale and should be cleaned up. Tell the user: "Run `github-issue` (the CLI command) to auto-clean merged worktrees."

### When to Audit

- **Always** run the audit on invocation, even when the user specifies a specific issue number. Report stale worktrees before proceeding to the requested issue.
- If the user asked to list/check status (not work on a specific issue), stop after the report.
- If a worktree exists for the requested issue, include its state in the routing decision.

## Detection Algorithm

Check signals in this priority order. The first match wins.

```
1. Is there a PR for this issue's branch?
   ├─ PR merged        → DONE (report completion; cleanup is bash's job in worktree mode)
   ├─ PR changes_requested → REVAMP
   ├─ PR approved      → READY (merge-ready; report status)
   ├─ PR open, pending → READY (awaiting review; report status)
   └─ PR closed (not merged) → report; offer reopen/new-PR/abandon

2. Does a feature branch exist for this issue?
   ├─ Commits on branch + uncommitted changes → IMPLEMENT (in progress)
   ├─ Commits on branch, clean tree          → VERIFY (or READY if already verified)
   ├─ No commits, uncommitted changes        → IMPLEMENT (in progress)
   ├─ No commits, clean tree, plan exists    → IMPLEMENT (plan ready, not started)
   └─ No commits, clean tree, no plan        → ASSESS (branch created, nothing done)

3. No branch, no PR
   └─ ASSESS (fresh start)
```

## Signal Commands

| Signal | Command | Parse |
|--------|---------|-------|
| Find branch for issue | `git branch -l '*/<issue-number>-*'` | Branch name or empty |
| PR for branch | `gh pr list --head <branch> --json number,state,reviewDecision,url` | JSON array |
| PR review status | `gh pr view <url> --json reviewDecision --jq '.reviewDecision'` | APPROVED, CHANGES_REQUESTED, or empty |
| PR merge status | `gh pr view <url> --json state --jq '.state'` | OPEN, MERGED, CLOSED |
| PR review comments | `gh pr view <url> --json reviews --jq '.reviews[]'` | Array of review objects |
| PR check status | `gh pr checks <url>` | Check names + pass/fail |
| Commits on branch | `git rev-list --count <default>..<branch>` | Integer |
| Uncommitted changes | `git status --porcelain` | Lines or empty |
| Default branch | `git symbolic-ref refs/remotes/origin/HEAD` | Branch name |

## Worktree Mode vs Standalone Mode

### Worktree Mode

The bash script (`github-issue.sh`) launched Claude inside a worktree. Additional signals available:

- **`.worktree-state.json`** exists in the worktree root
- Fields: `type`, `phase`, `branch`, `wt_path`, `session_id`, `pr_url`, `issue_number`, `issue_title`, `issue_body`
- The system prompt includes the issue body and branch name
- Phase field tracks bash's lifecycle: `setup`, `claude_running`, `claude_exited`, `pushing`, `pr_created`

Read the state file first, then augment with live gh/git signals (the state file may be stale).

### Standalone Mode

No state file. No worktree. Claude was invoked directly in Claude Code.

- Must determine the issue number from the user's request (e.g., "#42", "issue 42", URL)
- Fetch issue metadata: `gh issue view <number> --json title,body,labels,state`
- Search for existing branches: `git branch -a -l '*/<issue-number>-*'`
- Search for existing PRs: `gh pr list --search "head:<branch-pattern>" --json number,state,url`
- If no branch exists, Claude creates one following conventions (see conventions.md)

## Edge Cases

**Ambiguous branch match:** Multiple branches match the issue number pattern (e.g., multi-PR issue). List them and ask the user which one to work on.

**Stale state file:** The `.worktree-state.json` says `phase: claude_running` but the PR is already merged. Live signals override the state file — route to DONE.

**Offline / gh unavailable:** If `gh` commands fail (no auth, no network), fall back to git-only signals. Report that PR status couldn't be checked and suggest the user verify manually.

**Issue already closed:** If `gh issue view` shows the issue is closed, check whether there's a merged PR. If yes, report completion. If no merged PR, the issue may have been closed manually — ask the user what to do.

**No remote tracking:** Branch exists locally but hasn't been pushed. Route to IMPLEMENT or VERIFY based on commit count, and note that the branch needs pushing before PR creation.
