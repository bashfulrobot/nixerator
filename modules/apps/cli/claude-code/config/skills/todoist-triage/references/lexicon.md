# The wizard lexicon

The fixed keyword set the Phase-2 walk accepts, shown as the action line on every
card. Each keyword has an exact behaviour; every keyword that writes to Todoist is
backed by a deterministic script (the model only resolves the keyword and its
arguments). This file is the strong per-keyword contract.

## Parsing

- **First token is the keyword; the rest is its argument.** Natural phrasing maps
  to the obvious keyword ("move it to waiting customer" → `col Waiting Customer`).
- **Input that doesn't resolve to a keyword re-shows this menu.** Never treat a
  stray line as a `log` (or any other write).
- **The current task is implicit** — keywords never need a task ref; the wizard
  holds it.
- **Stay on the task until an explicit `next`/`skip`.** Multiple keywords per task
  are normal (a stalled wait is often `col` + `defer` + `nudge`). The walk never
  auto-advances.

## Gate

Typing a keyword IS the approval.

- **Internal (immediate):** `log`, `link`, `defer`, `col`, `prio`, `fixref`,
  `escalate`, `draft` — run on the keyword; reversible.
- **Completion (confirm per task):** `done`, `drop`, `merge`.
- **Outward (full gate):** `nudge`, `email`, `teams` — draft → text-polish →
  mandatory preview → explicit "send" that turn → `/slack-post` →
  capture permalink → log. Never auto-send.

## Prose cleaning (everything runs through text-polish)

- **Outward** messages → `text-polish` (customer-facing → `writing-style`, which
  folds in text-polish).
- **Short internal work-log notes** (a line or two) → the text-polish concision
  ruleset below, applied inline — terse, de-slopped, no em/en-dashes.
- **Long-form internal writeups** → `text-polish`.

`text-polish` humanizes and tightens in one pass, so never call `humanizer` on
top of it.

Concision ruleset for short internal notes (apply inline, no `claude -p`): say the
same thing in as few words as possible; cut filler and hedging; active voice;
prefer short common words; no em/en-dashes (use a comma or period); no anti-slop
words (additionally, crucial, delve, enhance, seamless, etc.); preserve URLs,
IDs, code, and quotations verbatim. (Canonical source: the prose rules in
`modules/apps/cli/text-polish/scripts/text-polish.sh`.)

## Logging guardrails (every writing keyword obeys these)

1. **Context-sourced arguments.** An argument may come from the conversation
   ("log the nudge I just sent"), not only from typed text. Resolving it is the
   model's job; the write stays deterministic.
2. **Show before write when reconstructed from context.** If the argument wasn't
   typed verbatim, echo the composed entry before writing.
3. **Link every external artifact reference — but only those.** An entry that
   references a Slack message, doc, email, Jira/Aha page, or a file on disk MUST
   carry its link/locator. Pure internal reasoning/status notes are legitimately
   link-less and are NOT nagged.
4. **No silent linkless log** for an external reference — ask for the link.
5. **No double-log after a real send** (the outward pipeline already logs).
6. **Report faithfully.** "Drafted" when nothing was sent; "Sent" only with a
   permalink.

## The keywords

### `log <text>` — append a work-log note
`scripts/td_worklog.sh <ref> --entry "<text>" [--link "label=url"]... [--next "<text>"]`
Comment-only; never changes date/priority/status. Argument may be context-sourced
(guardrail 1-2). Short → concision pass; long → text-polish.

### `link <url> [label]` — file a URL/locator into the log
`scripts/td_worklog.sh <ref> --entry "<what this is>" --link "<label>=<url>"`
Use when Dustin pastes or points at a link; label it.

### `defer [<when>]` — reschedule + log why
`scripts/td_defer.sh <ref> <date> --reason "<why>" [--next "<text>"] [--remind-before <dur>]`
No date → the standing horizon (next business day + 3, skip weekends). A known
future date always wins. Recurrence-safe.

### `col [<name>]` — move to a board column + log
`scripts/td_move.sh <ref> "<Column>" --reason "<why>"`
No name → accept the already-applied auto-move (no-op). `Kong*` only. Columns per
`references/kanban-board.md`.

### `prio <p1-p4>` — reprioritize (up or down) + log
`scripts/td_reprioritize.sh <ref> <p1|p2|p3|p4> --reason "<why>"`

### `fixref <what>` — flag a wrong/closed reference OR correct a prior note
`scripts/td_worklog.sh <ref> --verb correct-reference --entry "Correction: <what>" [--link ...]`
Posts a correction note; never silently rewrites the title.

### `escalate [<col>]` — flag risk / customer-blocker + move + log
`scripts/td_escalate.sh <ref> [--to "! Customer Blocker"|"Engineering"] --reason "<why>"`
Default column `! Customer Blocker`. Distinct from `nudge`.

### `draft <channel>` — prepare an outward message, log as NOT sent
`scripts/td_draft.sh <ref> --channel <slack|email|teams> --to "<who>" --text "<msg>" [--link ...]`
Composes + text-polishes the message, logs it "Drafted, not sent". NEVER sends. The
send is a later `nudge`/`email`/`teams`.

### `done <reason>` — complete (log the reason first)
`scripts/td_complete.sh <ref> --reason "<why done>" [--forever]`
Confirm per task. `--forever` stops recurrence.

### `drop <reason>` — close as no-longer-relevant
`scripts/td_drop.sh <ref> --reason "<why it stopped mattering>"`
Confirm per task.

### `merge <survivor> <loser>...` — fold duplicates into one survivor
`scripts/td_merge.sh --survivor <ref> --loser <ref>... [--survivor-url <url>] --reason "<why>"`
"Is this a duplicate" is Dustin's call; one confirm authorises the closes.

### `nudge` / `email` / `teams` — send an outward message (full gate)
Through the pipeline in `references/slack-message-pipeline.md`. Post-send the log
is automatic (`--verb send`, with the permalink). Email → Gmail draft via `gws`;
Teams → clipboard hand-send.

### `dig [<target>]` — on-demand deep research (read-only)
Run `scripts/dig_fetch.sh <ref>` to harvest breadcrumbs, then: report the delta
since the last log, follow the breadcrumbs (`references/data-sources.md`), verify
every reference is still the right/open one, surface new docs. Targeted forms:
`dig thread`, `dig ticket`, `dig <url>`. Output prose is text-polished.

### Navigation / display
`more` (expand full comments/log) · `open` (`xdg-open` the task or a breadcrumb) ·
`skip`/`next` (advance, no change) · `back` (previous task) · `quit` (end walk) ·
`?`/`menu` (show this list).
