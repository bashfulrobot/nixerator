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

## The gate tiers

Dustin chose this model. Do not drift from it.

| Tier | Verbs | Gate |
|---|---|---|
| **Internal, batched** | `note`, `defer`, `link-log` | Show the batch, take **one** approval, then run them all. Reversible, touches nobody else. |
| **Completion** | `complete`, `drop`, `close-into` | **Its own confirm, per task.** Not folded into the internal batch. |
| **Merge** | `merge` | **One confirm**, because confirming the duplicate call *is* confirming the closes it performs. |
| **Outward** | `send`, `teams`, `email` | Full gate, one at a time. Drafted, previewed, sent only on an explicit "send" in that turn. |

**The batch gate is an approval mechanism, not a presentation one.** Every task
in it still gets its own card first; the single "run these N?" question comes
*after* the walk, never instead of it. "Shown" means carded. If Dustin is reading
a gate question's option previews to learn what a task is, the walk did not
happen — that is the failure this line exists to prevent.

The invariant behind all of it: recommend, never auto-act. Nothing outward-facing
leaves without Dustin's explicit yes in the moment.

## Internal, batched

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

### `link-log` — file a pasted URL under the right task

Dustin pastes a Slack, Aha, Jira, or doc URL. Match it against open task titles
and comments, **propose** the target task, and confirm before writing. The match
is a suggestion; the confirmation is his.

```bash
scripts/td_worklog.sh <task-ref> --entry "<what this link is>" --link "<label>=<url>"
```

## Completion

### `complete` — mark a task done

```bash
td task complete <task-ref>          # --forever to stop recurrence
scripts/td_worklog.sh <task-ref> --entry "Completed. <why it's done>"
```

Log first, then complete, so the reason survives on the task. Only ever
*recommended*: Dustin confirms each one. A `likely-done` assessment is a
proposal, not a licence.

### `drop` — close something no longer relevant

Same as `complete`, with the reason recorded as why it stopped mattering:

```bash
scripts/td_worklog.sh <task-ref> --entry "Dropped: no longer relevant. <why>"
td task complete <task-ref>
```

### `close-into X,Y` — fold this task into others, then close it

For work that has been absorbed elsewhere rather than finished:

1. Cross-reference onto each survivor:
   `scripts/td_worklog.sh <X> --entry "Absorbed <this task>." --link "<title>=<url>"`
2. Point this task at them, then close it:
   `scripts/td_worklog.sh <ref> --entry "Closed into <X>, <Y>." --link ... && td task complete <ref>`

## Merge

### `merge` — collapse duplicates into one survivor

For several tasks that are really one thread. Surface the survivor and exactly
which tasks get closed, take one confirm, then:

1. Rename the survivor if a clearer title fits: `td task update <survivor> --content "<title>"`
2. Pull every link and fact from the losers into the survivor with `note`.
3. Pointer-comment each loser, then close it:
   `scripts/td_worklog.sh <loser> --entry "Merged into <survivor title>." --link "survivor=<url>"`
   followed by `td task complete <loser>`.

"Is this actually a duplicate" is Dustin's call, never the skill's. That call is
the gate, and it is also what authorizes the closes.

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
