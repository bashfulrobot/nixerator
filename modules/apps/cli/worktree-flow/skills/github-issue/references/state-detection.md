# State Detection (v3)

The `github-issue status <number>` command detects the current lifecycle state. It returns `workflow_step` (authoritative position in the state machine) and a legacy `state` field for backward compatibility.

## State File Schema (v3)

Path: `<worktree>/.worktree-state.json` (`.gitignore`d)

```json
{
  "version": 3,
  "type": "issue",
  "issue_number": "42",
  "issue_title": "Add JWT auth",
  "issue_body": "...",
  "branch": "feat/42-add-jwt-auth",
  "base_ref": "origin/main",
  "wt_path": "/absolute/path/to/.worktrees/issue-42",
  "pr_url": "",
  "session_id": "",

  "workflow_step": "implement",
  "workflow_detail": {
    "complexity": "standard",
    "plan_file": "PLAN.md",
    "review_stage": null,
    "revamp_round": 0,
    "blockers": [
      {"number": 40, "state": "OPEN", "title": "Refactor token storage"}
    ],
    "open_threads": [
      "verify intermittent test failure in src/auth.test.ts:142"
    ]
  },
  "step_history": [
    {"step": "setup",  "completed_at": "2026-04-23T10:00:00Z", "note": "Worktree created from origin/main."},
    {"step": "assess", "completed_at": "2026-04-23T10:05:00Z", "note": "Auto-classified as standard (all three signals present)."},
    {"step": "plan",   "completed_at": "2026-04-23T10:15:00Z", "note": "Plan written with 3 tasks covering middleware + tests + docs."}
  ],

  "started_at": "2026-04-23T09:50:00Z",
  "updated_at": "2026-04-23T10:20:00Z"
}
```

### v3 changes vs v2

- `base_ref` (string) — the ref the branch was pinned to at `setup`. Defaults to `origin/<default-branch>`. Used by pre-push rebase and touched-file overlap detection.
- `workflow_detail.blockers` — array of `{number, state, title}` parsed from issue body (`Blocked by #N`, `Depends on #N`, `Requires #N`, `Needs #N`). The v2 scalar `blocker` field is migrated into a single-element array.
- `workflow_detail.open_threads` — freeform array of short strings. Loose ends the agent noticed but hasn't resolved. Read on resume; add during transitions via `--detail-json '{"open_threads": ["..."]}'`.
- `step_history[].note` — required non-empty string on each transition. Backfilled as `""` for v2 entries; new entries are rejected without `--note`.

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
| `waiting` | Both reviews done, auto-merge enabled, waiting for CI + branch protection |
| `revamp` | Reviewer requested changes |
| `ci_fix` | Post-push CI failure — diagnose and fix (distinct from `revamp`) |
| `done` | PR merged |
| `closed` | PR closed without merge |

## Status Response

```json
{
  "issue_number": 42,
  "state": "IMPLEMENT",
  "detail": "in progress (3 commits)",
  "worktree": "/path/to/.worktrees/issue-42",
  "branch": "feat/42-add-jwt-auth",
  "workflow_step": "implement",
  "workflow_detail": {"complexity": "standard", "plan_file": "PLAN.md", "blockers": [...], "open_threads": [...]},
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

The `status` command reconciles `workflow_step` with git/PR/CI signals:

| `workflow_step` | Signal | Resolution |
|----------------|------------|------------|
| `plan`, `assess`, `design` | Commits exist on branch | Advance to `implement` |
| `push` | PR exists | Advance to `review_dev` |
| `waiting` | PR merged | Advance to `done` |
| `waiting` | Changes requested | Advance to `revamp` |
| `waiting`, `push`, `review_dev`, `review_security` | CI failing on open PR | Advance to `ci_fix` |
| `waiting` | PR closed without merge | Advance to `closed` |

Every reconciliation writes a new `step_history` entry with `reconciled: true` and a `note` describing the trigger, so resume-time agents can see why the state changed.

## Audit Response (Fleet Survey)

`github-issue audit` returns a graph, not just a list:

```json
{
  "worktrees": [
    {
      "issue_number": 42,
      "title": "...",
      "state": "IMPLEMENT",
      "workflow_step": "implement",
      "branch": "feat/42-...",
      "base_ref": "origin/main",
      "pr_url": null,
      "worktree": "/path/...",
      "blockers": [...],
      "touched_files": ["src/foo.ts", "src/bar.ts"]
    }
  ],
  "overlaps": [
    {"a": 42, "b": 43, "shared": ["src/foo.ts"]}
  ],
  "merge_order": [
    {"issue_number": 40, "title": "...", "pr_url": "...", "workflow_step": "waiting", "blocks": [42, 43]},
    {"issue_number": 42, "title": "...", "pr_url": "...", "workflow_step": "waiting", "blocks": []}
  ]
}
```

- `overlaps` surfaces worktree pairs that touch shared files — merge-conflict risk to plan around.
- `merge_order` ranks mergeable PRs so issues that unblock others merge first.

## Migration

`status` and `audit` auto-migrate state files forward:

| From | To | Transformation |
|------|----|----------------|
| v1 (no `version`) | v2 | Add `version: 2`, map `phase` → `workflow_step` |
| v2 | v3 | Add `base_ref` (defaulted to `origin/<default>`), convert scalar `blocker` → `blockers` array, add empty `open_threads`, backfill empty `note` on each `step_history` entry |

## Edge Cases Requiring AI Judgment

**PR closed without merge (`closed`):** Run `github-issue post-mortem <N>` for close-context, draft a comment on the issue, then ask the user: reopen the PR, create a new one, or abandon.

**Ambiguous complexity (during `assess`):** Read the issue body and classify as trivial / standard / complex. Auto-skip confirmation only when all three signals (prescriptive paths + prescriptive code + acceptance criteria) are present.

**Blocked work:** Open blockers are surfaced at `setup` from the `blockers` array. With the no-stacks rule, prefer to wait for the blocker to merge rather than branching off it.

**CI failures after PR:** `ci_fix` state. Use `github-issue check-ci <N>` for structured failure data. Distinct from `revamp`; do not invoke `receiving-code-review`.

**Merge conflicts at pre-push rebase:** The CLI aborts the rebase and returns an error. Follow the Merge Conflict Resolution procedure in `SKILL.md` — one attempt, mandatory post-resolve verification, escalate on failure.

**Offline / gh unavailable:** The script falls back to git-only signals when `gh` fails. PR state may be unknown.
