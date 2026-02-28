# todoist-report

Queries the Todoist API to generate a concise project status report. Shows tasks grouped by Kanban column (section), sorted by priority within each column, with their recent comment history — a 50,000-foot view of what's happening in a project.

## Enable

```nix
apps.cli.todoist-report.enable = true;
```

Enabled for all hosts via the `offcomms` suite.

## Prerequisites

`TODOIST_API_TOKEN` must be set in the environment. The intended workflow is via [shadowenv](https://shadowenv.github.io/) in a project directory:

```
# .shadowenv.d/env.lisp
(env/set "TODOIST_API_TOKEN" "your-token-here")
```

Or export it manually:

```bash
export TODOIST_API_TOKEN=your-token
```

## Usage

```bash
todoist-report [project-name] [--kong] [--json]
```

**Project name matching:**
1. Exact match (case-insensitive) — proceeds immediately if found
2. Substring match — if no exact match, searches by substring
3. Multiple matches — opens an interactive `gum filter` picker to select
4. No matches — error

This means `todoist-report "Kong"` goes straight through if you have a project named exactly "Kong", making it safe to use in scripts and AI pipelines.

### Human-readable report (default)

```bash
todoist-report "Kong"
```

Output:

```
Project: Kong  |  Generated: 2026-02-27
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OVERVIEW
  8 tasks  |  2 urgent  |  1 high  |  3 due within 7 days
  Last activity: 2026-02-25

In Progress
  ● [URGENT] Finalize vendor contract — In Progress — Due: Mar 1
    Updates:
      Feb 21 → "Sent contract draft to vendor"
      Feb 23 → "Vendor requested two changes to section 4"
      Feb 25 → "Sent final redlines to legal, waiting on sign-off"

  ● [HIGH] Backend API integration — Due: Mar 15
    Updates:
      Feb 20 → "Blocked on vendor response to auth question"

Review
  ● Design system audit — Due: Mar 20
    Updates:
      Feb 22 → "Completed component inventory, starting gap analysis"

Todo
  ● Onboarding documentation
    (no updates yet)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

Tasks are grouped by Kanban column (section) in board order. Within each column, tasks are sorted by priority descending, then due date ascending. Overdue tasks are flagged with `⚠ OVERDUE`.

### JSON output (for AI agent consumption)

```bash
todoist-report "Kong" --json
```

Returns structured JSON including the last 5 comments per task with full content:

```json
{
  "project": "Kong",
  "generated": "2026-02-27T12:00:00Z",
  "tasks": [
    {
      "id": "...",
      "content": "Finalize vendor contract",
      "priority": 4,
      "priority_label": "urgent",
      "section": "In Progress",
      "due": "2026-03-01",
      "latest_comment": {
        "content": "Sent final redlines to legal, waiting on sign-off",
        "posted_at": "2026-02-25T10:00:00Z"
      },
      "recent_comments": [...],
      "comment_count": 3
    }
  ]
}
```

### --kong flag: all Kong projects at once

```bash
todoist-report --kong
```

Matches all Todoist projects whose name starts with "kong" (case-insensitive) and runs the full report pipeline for each. No project-name argument needed. Reports are separated by a visual divider:

```
Project: Kong API  |  Generated: 2026-02-27
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
OVERVIEW
  ...

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Project: Kong Platform  |  Generated: 2026-02-27
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
...
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### Pipe to an AI agent

```bash
todoist-report "Kong" --json | claude -p "Summarize this project status and flag blockers"
todoist-report "Kong" --json | jq .

# All Kong projects in one shot — returns a JSON array (not a single object)
todoist-report --kong --json | jq 'length'
todoist-report --kong --json | jq '.[0].project'
todoist-report --kong --json | claude -p "Summarize all Kong project statuses and flag blockers"
```

The project name must be an exact match when piping, so the interactive picker is never triggered.

## Priority mapping

The Todoist API inverts the GUI priority numbers — P1 in the GUI is the most urgent and maps to API value `4`.

| GUI label | API value | Report label |
|-----------|-----------|--------------|
| P1        | 4         | `[URGENT]`   |
| P2        | 3         | `[HIGH]`     |
| P3        | 2         | `[MEDIUM]`   |
| P4        | 1         | *(none)*     |

## Notes

- Progress is printed to stderr via `gum log` so stdout stays clean for piping.
- Up to 5 most recent comments are shown per task, oldest-to-newest.
- Comments in human-readable mode are truncated at 120 characters.
- The token is never stored in nix — it comes entirely from the environment.
- Uses the Todoist REST API v1 (`api.todoist.com/api/v1`) with cursor-based pagination.
- `--kong --json` returns a JSON array; a single-project `--json` returns a single object.
