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

srv, qbert and the Mac all peer with each other for this folder, so any one of
them can be off and the other two still sync. The Mac and srv share only this
folder (the Mac's dev and upsight folders go to qbert alone).
UNVERIFIED until a report written on srv shows up on the Mac with qbert stopped.

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

With `flagRepeatDays` above 0 the runner also writes a one-line comment on each
idle task: `Idle Nd, flagged by srv (idle-flag)`. Todoist's timestamp is the
date, and the state label already says who holds the ball. These are real writes
to Todoist. The
`idle-flag` text keeps those comments out of the activity that decides idleness,
and a task gets another comment only after `flagRepeatDays` days. A failed comment
is counted in the report and does not stop the run.

### Priority tiers on srv

| Query | Filter | Runs | Idle for | Comment again after |
|---|---|---|---|---|
| `kong-p1-idle` | `p1 & #kong-*` | Mon to Fri 06:00 | 2 days | 7 days |
| `kong-p2-idle` | `p2 & #kong-* & (overdue \| today \| no date)` | Mon, Thu 06:05 | 5 days | 14 days |
| `kong-p3-idle` | `p3 & #kong-* & (overdue \| today \| no date)` | Mon 06:10 | 14 days | none (report only) |
| `waiting-stale` | `(@waiting-customer \| @waiting-internal) & (overdue \| today \| no date)` | Mon, Wed, Fri 06:15 | 5 days | 14 days |
| `overdue-chronic` | `overdue & !(due after: -7 days) & (p1 \| p2)` | Mon 06:20 | none (updated age only) | none |
| `inbox-stale` | `#Inbox & created before: -3 days` | Mon, Thu 06:25 | none (updated age only) | none |

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
- The orchestrator's worklog (dk 4.12) is one comment per action, appended, with
  no `next:` field. The `idle-flag` note is therefore a short fixed line and the
  runner reads no earlier comment.
- `orch.py prepare` lists comments newer than the last sync as new findings, so
  an `idle-flag` comment shows up there once.
- The orchestrator's own `audit <filter>` checks title, description and label
  conformance, so srv only flags a missing type label (`NO TYPE LABEL`) and does
  not duplicate that check.

Todoist rate limits the account with HTTP 429 (official limit: 1000 partial plus
100 full sync requests per user per 15 minutes), and its `retry-after` has run
past 20 minutes after a burst of calls (seen 2026-10-31). Three rules keep the
jobs under it:

- **Spaced starts.** The six timers start 5 minutes apart (06:00 to 06:25, the
  four that read the activity feed first) with 1 minute of random delay.
  triage-rank runs at 05:30 and takes no lock (2 calls). A lock in
  `/var/lib/automations` (mode 0700) makes the six td jobs run one at a time,
  even after a catch-up at boot. A job that waits 15 minutes for the lock logs a
  skip and exits 0, so the old report stays and is not marked `failed`. The
  units have a 40 minute start timeout, so a stuck call cannot hold the lock.
- **One activity fetch.** The 30 day activity feed is fetched once and cached
  in `/var/lib/automations/activity-<since>.json` (mode 0600, 30 minute TTL,
  `activity-cache.sh`, at most 20 pages). The jobs that start inside the window
  reuse it, and a job that writes idle flags records them in the cache so the
  next job does not flag the same task. After 2 failed flag comments in a row
  the job skips the rest and reports the count.
- **Careful retries.** Every `td` call goes through `td_retry` in
  `modules/server/automations/td-lib.sh`, shared with triage-rank. It leaves
  1.5 seconds between calls. On a 429 it waits the Retry-After seconds when `td`
  prints them, else 45 then 90 seconds, and stops after 3 calls. A Retry-After
  over 180 seconds stops at once. Any other error fails at once. A failed job
  makes `automations-failed@<job>` mark the report `failed`, and the next run
  restores it. Tests: `just test-td-lib`, `just test-activity-cache`.

Each run logs `td calls: N` at exit (`journalctl -u automations-td-<name>`).
Expected N: 2 (task list, project list), plus 1 per 1000 activity events on a
cache miss, plus 1 per idle-flag comment. triage-rank expects 2.
`todoist-report` stops at 400 requests, 10 pages per list or a 429, and logs its
request count. Do not trigger several queries back to back by hand.

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

## triage-rank

`server.automations.triageRank` ranks open Todoist tasks overnight for the claudoist top-5. Weekdays at 05:30 it runs two Todoist calls (a task query and a project list) and one `claude -p` call with every tool disabled and structured output, using the rules in `modules/server/automations/triage-rank/triage-policy.md`. It writes `reports/<host>/triage-rank/latest.md` and `latest.json`. Each task keeps the td-query shape and gains `rank`, `summary`, `reason` and `suggested_action`. The model also sees a short description per task to judge promises and blockers, and the report never carries it. For tasks whose project is exactly Inbox the model also proposes a title (80 characters), a description (280) and a type label (qa, followup, feature-request, meeting, initiative or none). Proposals pass the same cleaning as every other model field. A proposal on a non-Inbox id, or with an empty title, is dropped alone, and an unknown label is blanked. `latest.json` keeps `proposal` on each task and sets `proposal_advisory: true` at the top, so no consumer applies it automatically. A person applies one later through the orchestrator's check command. The markdown report lists id, current title, proposed title and label under "Inbox proposals" and never the original description. Inbox means the project Todoist flags as the inbox (`inboxProject`), never a project name, because a collaborator can rename a shared project. A proposal description can still paraphrase the task description, so `latest.json` stays as private as the task titles it already carries. Nothing is written to Todoist. An empty candidate day writes a valid empty report, which the claudoist helper logs once as unusable and then ignores. A failed run writes status `failed` through `automations-failed`, and the claudoist helper then ignores the old report.

It is read-only against Todoist and never sets `flagRepeatDays`. The Claude token resolves at run time through the gopass runner, the same entry `server.incidentInvestigator` uses. Run it by hand with `systemctl start automations-triage-rank`.
