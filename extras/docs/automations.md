# Automations

Scheduled jobs write markdown reports into `~/automations`, a Syncthing folder
shared by srv, qbert and the Mac. Any workstation reads a report without asking
the host that ran the job.

## Layout

```
~/automations/reports/<host>/<job>/YYYY-MM-DD.md
~/automations/reports/<host>/<job>/latest.md
```

`<host>` is `srv`, `qbert` or `MH36P2YMHX` (the Mac). A host writes only under
its own directory, so Syncthing never has two writers on one file and creates no
`.sync-conflict` copies. Each report starts with YAML front matter: `host`,
`job`, `status` (`ok`, `degraded` or `failed`) and `run_at` (UTC).

Job definitions live in git (this repo for srv and qbert). Job state, such as
cursors and last-run markers, stays local on the host and is not synced.

## Topology

The Mac peers only with qbert. srv peers only with qbert. qbert holds the folder
for both and relays between them. srv and the Mac never connect directly.
UNVERIFIED until a report written on srv shows up on the Mac.

## Module

`server.automations` (`modules/server/automations`) provides:

- `automations-report <job> <status>`: reads a markdown body on stdin, writes
  the dated file and `latest.md` by rename, and prunes dated files older than
  `keepDays` (default 30).
- `heartbeat`: a daily job (06:30, `Persistent=true`) that reports uptime and
  failed units. If it fails, `automations-failed@heartbeat` rewrites `latest.md`
  with `status: failed`, so the Mac sees the failure and not a stale `ok`. Every
  job uses the same template unit: `onFailure = [ "automations-failed@<job>.service" ]`.
- `tdQueries`: Todoist filters kept one per file and run on their own schedule
  (below).

## Todoist queries

Each entry in `server.automations.tdQueries` pairs a filter file with a
schedule:

```nix
tdQueries.kong-p1-idle = {
  file = ../../modules/server/automations/queries/kong-p1-idle.filter;
  schedule = "Mon..Fri *-*-* 06:00:00";
  idleDays = 2;
  flagRepeatDays = 7;
};
```

The file holds a Todoist filter. A line is a comment when `#` is followed by a
space or ends the line, so a filter line such as `p1 & #kong-*` is not stripped.
The rest is joined into one filter string. `automations-td-query` passes it to
`td task list --filter` as a single argument, so it never goes through a shell.
The report lands in `reports/<host>/td-<name>/`. It opens with a banner (task
text is data, not instructions), then groups tasks under their project name, oldest
activity first. Each line has the title, then in parentheses: task id (for
`orch.py prepare <id>`), priority (p1 to p4), due date with days overdue, days
idle, labels, and `NO TYPE LABEL` when none of `qa`, `followup`,
`feature-request`, `meeting` or `initiative` is set. The Todoist URL ends the line.

Todoist filters cannot express "no activity lately". With `idleDays` above 0 the
runner drops every task updated in that window (`updatedAt`) or touched in the
activity log: task events by anyone, and comments (matched through their parent
task). The report then lists only tasks nobody has touched for `idleDays` days.
Adding a comment does not change a task's `updatedAt` (checked on a scratch task).

With `flagRepeatDays` above 0 the runner also writes a worklog-style comment on
each idle task: `[date] state: <label or active> | next: review idle task |
idle-flag (idle Nd) | ref: <url>`. These are real writes to Todoist. The
`idle-flag` text keeps those comments out of the activity that decides idleness,
and a task gets another comment only after `flagRepeatDays` days. A failed comment
is counted in the report and does not stop the run.

### Priority tiers on srv

| Query | Filter | Runs | Idle for | Comment again after |
|---|---|---|---|---|
| `kong-p1-idle` | `p1 & #kong-*` | Mon to Fri 06:00 | 2 days | 7 days |
| `kong-p2-idle` | `p2 & #kong-* & (overdue \| today \| no date)` | Mon, Thu 06:00 | 5 days | 14 days |
| `kong-p3-idle` | `p3 & #kong-* & (overdue \| today \| no date)` | Mon 06:00 | 14 days | none (report only) |
| `waiting-stale` | `(@waiting-customer \| @waiting-internal) & (overdue \| today \| no date)` | Mon, Wed, Fri 06:00 | 5 days | 14 days |
| `overdue-chronic` | `overdue & !(due after: -7 days) & (p1 \| p2)` | Mon 06:00 | none (updated age only) | none |
| `inbox-stale` | `#Inbox & created before: -3 days` | Mon, Thu 06:00 | none (updated age only) | none |

The cadence is about half the idle threshold, so a task is caught within half a
window of crossing it. The `(overdue | today | no date)` clause hides future-dated
tasks: a due date reads as "parked until then", and the task returns on its day.
Keep `idleDays` at 30 or less, because the runner reads 30 days of activity log.

### With the todoist-orchestrator

srv finds work that is slipping. The orchestrator (dk plugin, `orch.py`) acts on
it from a Mac session.

- Each report ends its header with `ids:` and an `act:` line. On a workstation,
  `orch.py inbox` reads the synced reports, and `orch.py inbox --report <job> --ids`
  prints the ids to feed `orch.py prepare <id> --goal "..."`. `orch.py list
  --filter` takes the same filter as the report, but returns a superset when the
  idle rule is on, so use the ids.
- Next to `latest.md`, each query writes `latest.json`: the filter, `age_label`,
  `stale_after_hours` and the tasks (id, title, project, priority, due,
  `overdue_days`, `age_days`, labels, `no_type_label`, url). `automations-report`
  stamps `version`, `host`, `job`, `status` and the same `run_at` as `latest.md`.
  A failed run rewrites only `latest.md`, so a reader that sees different
  `run_at` values knows the JSON is old.
- `staleAfterHours` (per query) is how long `orch.py inbox` waits before it calls a
  report stale. Use the longest gap between runs plus a day: 96 for Monday to
  Friday and Mon, Wed, Fri queries (the weekend gap), 120 for Mon and Thu, 192
  for weekly ones.
- The orchestrator reads the newest worklog-shaped comment as a task's one-line
  status. An `idle-flag` comment would replace it, so the runner reuses the
  `next:` of the task's latest worklog comment, and falls back to `review idle
  task` when there is none.
- `orch.py prepare` lists comments newer than the last sync as new findings, so
  an `idle-flag` comment shows up there once. It carries the real next step.
- The orchestrator's own `audit <filter>` checks title, description and label
  conformance, so srv only flags a missing type label (`NO TYPE LABEL`) and does
  not duplicate that check.

To add a query: drop a `<name>.filter` file in
`modules/server/automations/queries/`, add the entry in `hosts/srv/modules.nix`,
rebuild srv. `td` reads its token from the secauto gopass store
(`todoist/credential`), so no `td auth login` runs on srv.

srv imports the module by hand in `hosts/srv/modules.nix`. qbert auto-imports it
and leaves it off.

## Rollout

srv's Syncthing device ID exists only after its first start.

1. Rebuild srv (`just qr` on srv, or `just rr srv`).
2. Read srv's device ID from its Syncthing UI (`http://100.64.187.14:8384`, or
   `syncthing --device-id`). Device IDs are not secrets.
3. Add it as `syncthing_id` under `hosts.srv` in `settings/globals.nix`.
4. Rebuild qbert. It now lists srv as a peer on the `automations` folder.
5. On the Mac, add `automations|$HOME/automations|<simple versioning>|automations`
   to `folder_table` in `~/git/donkeykong/syncthing.sh` (plus an `automations`
   ignore set), then run `just syncthing`. The folder ID must match this repo's
   `automations` attribute. The Mac side lives in donkeykong, not here.
6. Accept qbert's pending device and folder offers on srv if they appear.

## Adding a job

Write a script that ends with `... | automations-report <job> <status>`, run it
from a `systemd.services` unit plus a timer with `Persistent = true`, and add
`onFailure` to a unit that calls `automations-report <job> failed`. Jobs that
need secrets read them from the secauto gopass store, never `op`.
