# Phase-2 macros: the verb vocabulary

Every Phase-2 action is one of the verbs below. Each verb is a fixed, named
operation with its conventions already baked in, so Dustin answers with a verb
instead of re-dictating the recipe, and the standing rules never need restating.

Two properties make this work, and both are deliberate:

- **Every verb that writes also logs.** The work-log entry is fused into the
  action, not bolted on after. That is why `defer` is a script and not a bare
  `td task reschedule`: a fused action cannot skip its log.
- **Mechanics are delegated, policy is not.** These verbs shell out to `td`
  (whose surface the `todoist-cli` skill owns). This file owns the triage
  policy: which verb, which tier, what gets logged.

## The gate model (keyword wizard)

Typing a keyword IS the approval — the old "internal, batched (one approval)" tier
is retired.

| Tier | Verbs | Gate |
|---|---|---|
| **Internal** | `note`/`log`, `link-log`/`link`, `defer`, `move`/`col`, `reprioritize`/`prio`, `correct-reference`/`fixref`, `escalate`, `draft` | Execute immediately on the keyword. Reversible, touches nobody else. |
| **Completion** | `complete`/`done`, `drop`, `close-into`, `merge` | Confirm per task. Never auto. |
| **Outward** | `send`/`nudge`, `teams`, `email` | Full gate, one at a time, explicit "send" that turn. |

Still true: every writing verb logs itself through `td_worklog.sh`; report
faithfully ("Drafted" vs "Sent").

Every internal keyword is **carded first**: the task's card (with any auto
column-move already shown) is what Dustin reads before he types the keyword.
Typing the keyword is the approval — there is no separate "run these N?" batch
question. The walk stays on the task until an explicit `next`/`skip`, so stacking
`col` + `defer` + `nudge` on one task is normal.

The invariant behind all of it: the only thing the skill does on its own is the
auto column-move (shown and logged); every completion is confirmed, and nothing
outward-facing leaves without Dustin's explicit yes in the moment.

## Internal (immediate)

### `note` — record something in the work log

```bash
scripts/td_worklog.sh <task-ref> --entry "<text>" [--link "label=url"]... [--next "<text>"]
```

Idempotent: one "Triage log <date>" comment per task per day, appended to on
repeat calls rather than duplicated. Humanize the entry text first.

**`note` never touches due date, priority, or status.** It only writes a comment.
Changing a date is `defer`; changing status is `complete` or `drop`. If a note
and a date change both apply, that is `defer`, which does both.

### `defer` — move the date and say why

```bash
scripts/td_defer.sh <task-ref> <date> --reason "<why>" [--next "<text>"] \
                    [--remind-at "<datetime>" | --remind-before <duration>]
```

Reschedules (recurrence-safe) and logs the rationale as one move. Preview with
`--dry-run` when the date is uncertain.

Pick the date from the assessment, not from habit. Waiting on a non-responsive
person means defer plus a drafted nudge. Blocked until a known date means defer
to that date. Do not push everything to tomorrow.

**Never use `td task update --due` to move a date.** It overwrites the due string
and destroys recurrence on a recurring task. `td task reschedule` preserves both
recurrence and time-of-day, and is what `td_defer.sh` calls.

### `move` — put the task in the right board column

```bash
scripts/td_move.sh <task-ref> "<Column>" --reason "<why>" [--next "<text>"]
```

Moves the task to a Kanban column (Todoist section) and logs the move as one
action. Columns are the stable vocabulary in `references/kanban-board.md`; the
column name resolves within the task's own project, so no id lookup is needed.
Preview with `--dry-run` when unsure the column exists in that project.

**Only `Kong*` board projects have columns.** Pick the column from the
assessment, not from habit — `waiting-on-them` (customer) → `Waiting Customer`,
`likely-done` pending sign-off → `Waiting Validation`, a "write this up in
Confluence" task → `Capture Data`. Never move `Reoccurring`. The full routing
table lives in `references/kanban-board.md`; read it before recommending a
column.

### `reprioritize` — change the priority, up or down

```bash
scripts/td_reprioritize.sh <task-ref> <p1|p2|p3|p4> --reason "<why>" [--next "<text>"]
```

Sets the priority (`p1` = highest) and logs why, as one action. This supersedes
the old downgrade-only treatment: triage raises urgency (a wait that became a
customer blocker → `p1`) as well as lowers it. Pass the friendly `p1..p4` label —
never the raw API value, which is inverted (`4` = highest); the script and `td`
speak `p1..p4`.

### `escalate` — flag risk / customer-blocker

```bash
scripts/td_escalate.sh <ref> [--to "! Customer Blocker"|"Engineering"] --reason "<why>"
```

Moves the task to a blocker/eng column and logs the escalation, fused. Default
`! Customer Blocker`. Distinct from `send`/`nudge`: escalation is an internal
status change, not an outward message.

### `draft` — prepare an outward message, logged as NOT sent

```bash
scripts/td_draft.sh <ref> --channel <slack|email|teams> --to "<who>" --text "<msg>" [--link "label=url"]
```

Records a prepared message on the work log as "Drafted, not sent". NEVER sends.
Closes the ready-to-send/actually-sent limbo. The send is a later
`send`/`teams`/`email`. Message text is humanized (outward prose).

### `link-log` — file a pasted URL under the right task

Dustin pastes a Slack, Aha, Jira, or doc URL. Match it against open task titles
and comments, **propose** the target task, and confirm before writing. The match
is a suggestion; the confirmation is his.

```bash
scripts/td_worklog.sh <task-ref> --entry "<what this link is>" --link "<label>=<url>"
```

## Completion

### `complete` / `done`

```bash
scripts/td_complete.sh <ref> --reason "<why it's done>" [--forever]
```

Logs the reason first, then completes. Confirm per task.

### `drop`

```bash
scripts/td_drop.sh <ref> --reason "<why it stopped mattering>"
```

### `close-into X,Y` — fold this task into others, then close it

For work that has been absorbed elsewhere rather than finished:

1. Cross-reference onto each survivor:
   `scripts/td_worklog.sh <X> --entry "Absorbed <this task>." --link "<title>=<url>"`
2. Point this task at them, then close it:
   `scripts/td_worklog.sh <ref> --entry "Closed into <X>, <Y>." --link ... && td task complete <ref>`

## Merge

### `merge`

```bash
scripts/td_merge.sh --survivor <ref> --loser <ref> [--loser <ref>...] [--survivor-url <url>] --reason "<why>"
```

Cross-references the survivor, pointer-comments each loser, closes the losers. One
confirm authorises the closes.

## Outward (full gate)

### `send` — post a Slack message as Dustin

The pipeline in `slack-message-pipeline.md` is not optional: draft, humanize,
text-polish, **mandatory preview**, **explicit send**, post via `/slack-post`
(never the Slack MCP), capture the permalink, log it.

Post-send, the log is automatic, not a separate request:

```bash
scripts/td_worklog.sh <task-ref> --entry "Sent nudge to <who> re <what>." \
  --link "nudge=<permalink>" --next "<what to watch for>"
```

### `teams` — hand-send where there is no API

For contacts on Teams. Humanize, text-polish, strip Markdown (Teams will not
render it), copy to the clipboard, and stop. Dustin pastes it, gives back the
message link, and only then does the log land.

```bash
export WAYLAND_DISPLAY=$(basename "$(ls /run/user/$(id -u)/wayland-* 2>/dev/null | grep -v '\.lock$' | head -1)")
printf '%s' "<polished text>" | wl-copy
```

If `WAYLAND_DISPLAY` is empty the host is headless and there is no clipboard.
Say so rather than reporting a silent success.

### `email` — draft a Gmail reply

Gmail draft via `gws`, correctly threaded (In-Reply-To / References / threadId,
clean To). Customer-facing prose goes through `writing-style`. **Never
auto-send**, leave the draft. Log it with a link to the thread.

## Reporting rule

A drafted-not-sent message is logged as "Drafted". A sent one is logged as
"Sent" with its permalink. Never launder a draft into a send, in the work log or
in the summary back to Dustin.
