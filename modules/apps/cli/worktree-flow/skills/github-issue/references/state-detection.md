# State Detection (v2)

The `github-issue status <number>` command detects the current lifecycle state. It returns the v2 `workflow_step` (authoritative position in the state machine) and a legacy `state` field for backward compatibility.

## State File Schema (v2)

Path: `<worktree>/.worktree-state.json` (`.gitignore`d)

```json
{
  "version": 2,
  "type": "issue",
  "issue_number": "42",
  "issue_title": "Add JWT auth",
  "issue_body": "...",
  "branch": "feat/42-add-jwt-auth",
  "wt_path": "/absolute/path/to/.worktrees/issue-42",
  "pr_url": "",
  "session_id": "",

  "workflow_step": "implement",
  "workflow_detail": {
    "complexity": "standard",
    "plan_file": "PLAN.md",
    "review_stage": null,
    "revamp_round": 0,
    "blocker": null
  },
  "step_history": [
    {"step": "setup", "completed_at": "2026-04-15T10:00:00Z"},
    {"step": "assess", "completed_at": "2026-04-15T10:05:00Z"},
    {"step": "plan", "completed_at": "2026-04-15T10:15:00Z"}
  ],

  "started_at": "2026-04-15T09:50:00Z",
  "updated_at": "2026-04-15T10:20:00Z"
}
```

## Workflow Steps

| Step | Meaning |
|------|---------|
| `assess` | Worktree created, issue needs complexity classification |
| `design` | Complex issue — brainstorming/design phase |
| `plan` | Writing implementation plan |
| `implement` | Active development |
| `verify` | Running tests/linters/build |
| `push` | Ready to push branch and create/update PR |
| `review_dev` | PR created, dev review stage |
| `review_security` | Dev review done, security review stage |
| `waiting` | Both reviews done, waiting for external review |
| `revamp` | PR has changes requested |
| `done` | PR merged |
| `closed` | PR closed without merge |

## Status Response (v2)

```json
{
  "issue_number": 42,
  "state": "IMPLEMENT",
  "detail": "in progress (3 commits)",
  "worktree": "/path/to/.worktrees/issue-42",
  "branch": "feat/42-add-jwt-auth",
  "workflow_step": "implement",
  "workflow_detail": {"complexity": "standard", "plan_file": "PLAN.md", ...},
  "step_history": [...],
  "title": "Add JWT auth",
  "issue_body": "Full issue body text...",
  "pr": {
    "url": "https://github.com/user/repo/pull/55",
    "state": "OPEN",
    "review_decision": "CHANGES_REQUESTED",
    "number": 55
  }
}
```

The `pr` field is `null` when no PR exists. The `state` field is the legacy detection result — `workflow_step` is authoritative.

## Auto-Reconciliation

The `status` command reconciles `workflow_step` with git/PR signals:

| `workflow_step` | Git signal | Resolution |
|----------------|------------|------------|
| `plan` or `assess` | Commits exist on branch | Advance to `implement` |
| `push` | PR exists | Advance to `review_dev` |
| `waiting` | PR merged | Advance to `done` |
| `waiting` | Changes requested | Advance to `revamp` |
| `waiting` | PR closed | Advance to `closed` |

## v1 Migration

State files without a `version` field are auto-migrated by `status`:

| v1 `phase` | v2 `workflow_step` |
|-------------|-------------------|
| `setup` | `assess` |
| `claude_running` | `implement` |
| `claude_exited` | `implement` |
| `pushing` | `push` |
| `pr_created` | `waiting` |

## Edge Cases Requiring AI Judgment

**PR closed without merge (`closed`):** Ask the user: reopen the PR, create a new one, or abandon the issue.

**Ambiguous complexity (during `assess`):** Read the issue body and classify as trivial/standard/complex.

**Blocked work:** Not detectable by the script. If the user reports a blocker, note it and suggest exiting.

**CI failures after PR:** Use `github-issue check-ci <N>` for structured failure data.

**Offline / gh unavailable:** The script falls back to git-only signals when `gh` fails. PR status may be unknown.
