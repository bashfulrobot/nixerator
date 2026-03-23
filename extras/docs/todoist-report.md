# todoist-report

Queries Todoist API for project status: tasks grouped by Kanban column, sorted by priority, with recent comment history.

## Enable

```nix
apps.cli.todoist-report.enable = true;   # also enabled via offcomms suite
```

## Prerequisites

`TODOIST_API_TOKEN` must be set. Recommended via [shadowenv](https://shadowenv.github.io/):

```lisp
# .shadowenv.d/env.lisp
(env/set "TODOIST_API_TOKEN" "your-token-here")
```

## Usage

```bash
todoist-report [project-name] [--kong] [--json]
```

**Project matching**: exact (case-insensitive) > substring > interactive `gum filter` picker > error.

### Modes

- **Default** -- human-readable report with overview, tasks by section, comments
- **`--json`** -- structured JSON with last 5 comments per task (single object)
- **`--kong`** -- all projects starting with "kong" (no project arg needed)
- **`--kong --json`** -- returns JSON array (not single object)

### Pipe to AI

```bash
todoist-report "Kong" --json | claude -p "Summarize and flag blockers"
todoist-report --kong --json | claude -p "Summarize all Kong project statuses"
```

Exact match required when piping (interactive picker never triggered).

## Priority Mapping

| GUI | API value | Report label |
| --- | --------- | ------------ |
| P1  | 4         | `[URGENT]`   |
| P2  | 3         | `[HIGH]`     |
| P3  | 2         | `[MEDIUM]`   |
| P4  | 1         | _(none)_     |

## Notes

- Progress logged to stderr via `gum log` (stdout clean for piping)
- Up to 5 recent comments per task, oldest-to-newest; truncated at 120 chars in human mode
- Token never stored in nix -- environment only
- Uses Todoist REST API v1 with cursor-based pagination
