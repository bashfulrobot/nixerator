# State Detection

The `github-issue status <number>` command detects the current lifecycle state automatically. This reference documents the states and edge cases that need AI judgment.

## States

| State | Meaning | What the script checked |
|-------|---------|------------------------|
| `NEW` | No worktree exists for this issue | No `../.worktrees/issue-<N>` directory |
| `ASSESS` | Worktree exists, no work started | Branch has 0 commits, clean tree |
| `IMPLEMENT` | Work in progress | Commits on branch and/or uncommitted changes |
| `READY` | PR open, awaiting or passed review | PR state=OPEN, review=APPROVED or pending |
| `REVAMP` | PR has changes requested | PR state=OPEN, review=CHANGES_REQUESTED |
| `DONE` | PR merged | PR state=MERGED or branch merged into default |
| `CLOSED` | PR closed without merge | PR state=CLOSED |

## JSON Response

```json
{
  "issue_number": 42,
  "state": "REVAMP",
  "detail": "changes requested",
  "worktree": "/path/to/.worktrees/issue-42",
  "branch": "feat/42-add-jwt-auth",
  "phase": "pr_created",
  "title": "Add JWT auth",
  "pr": {
    "url": "https://github.com/user/repo/pull/55",
    "state": "OPEN",
    "review_decision": "CHANGES_REQUESTED",
    "number": 55
  }
}
```

The `pr` field is `null` when no PR exists. The `phase` field tracks the bash workflow phase (may be stale — `state` is authoritative).

## Edge Cases Requiring AI Judgment

**PR closed without merge (`CLOSED`):** The script detects the state but can't decide what to do. Ask the user: reopen the PR, create a new one, or abandon the issue.

**Ambiguous complexity (during ASSESS):** The script doesn't assess complexity — that's the AI's job. Read the issue body and classify as trivial/standard/complex.

**Blocked work:** Not detectable by the script. If the user reports a blocker, note it and suggest exiting. On resume, ask if it's resolved.

**CI failures after PR:** Check with `gh pr checks <url>`. If failing, re-enter IMPLEMENT with the CI failure context.

**Offline / gh unavailable:** The script falls back to git-only signals when `gh` fails. PR status may be unknown — report this and suggest the user verify manually.

**Issue already closed:** If `gh issue view` shows the issue is closed but no merged PR exists, the issue may have been closed manually. Ask the user what to do.
