---
name: slack-todoist-triage
description: >-
  Walk through Todoist tasks that link to Slack threads (Kong-* customer
  projects first, then optionally Kong-cs and other Kong projects), and
  optionally sweep the last 2 weeks of the user's own Slack activity for
  threads not in Todoist. For each item, compare task state vs. thread
  state, classify as needs-action / needs-follow-up-ping / no-action,
  draft a reply, run it through `humanizer`, get explicit approval, and
  post via `/slack-post` (NEVER the Slack MCP). The user reviews every
  draft before anything goes out.

  Use whenever the user says `/slack-todoist-triage`, "triage my slack",
  "go through my followups", "check my slack threads", "what threads
  need replies", "go through my Kong todoist tasks", "time to clear my
  slack", "slack catch-up", "process my followups", "review my open
  threads", or asks to systematically work through their Slack/Todoist
  queue. Trigger eagerly on phrases like "follow-ups", "overdue
  replies", "thread review", or "queue triage" in a Kong/customer
  context — the user is a Staff Technical CSM at Kong and this is a
  recurring workflow that they own.

  Do NOT trigger for one-off "send a slack message" requests (that's
  `/slack-post` directly), for adding/managing Todoist tasks (that's
  `/todoist-cli`), or for drafting customer messages without the triage
  loop (use `writing-style` + `humanizer` + `/slack-post` directly).
compatibility: >-
  Requires the `td` CLI (Todoist), the Slack MCP server (read-only
  use), the `/slack-post` skill (with credentials configured via
  `slack-token-refresh`), and the `humanizer` skill. Recommended:
  `writing-style` skill for voice matching.
---

# Slack–Todoist Triage

A loop for catching up on Slack threads that have gone stale. Runs in
two phases: first walk Todoist tasks that link to Slack threads, then
optionally sweep recent Slack activity that isn't in Todoist. For each
thread, you decide whether to act now, defer, or skip. When you act,
you stay in the driver's seat: you classify the response type, you
provide any substantive content the answer needs, and you approve the
final draft before it leaves the loop.

## Hard rules (no exceptions)

These are non-negotiable. They exist because a single misfire on a
customer-facing channel is worse than a hundred slow loops.

1. **Every outbound message goes through `/slack-post`. Never the Slack
   MCP for sending.** The Slack MCP's `slack_send_message`,
   `slack_send_message_draft`, and `slack_schedule_message` are off
   limits in this workflow. If `/slack-post` is unavailable for any
   reason (missing token, script error, network), abort the post and
   surface the error — do not fall back to the MCP. The MCP is fine for
   reads (`slack_read_thread`, `slack_search_*`, `slack_read_channel`,
   `slack_read_user_profile`); only sends are forbidden.

2. **Two approval gates per post, both honored.** The triage loop
   shows a draft and asks "approve?" — accept any clear yes ("yes",
   "looks good", "send it", a thumbs-up). Then hand off to `/slack-post`,
   which runs its own preview + explicit "send"/"ship it"/"post it"
   gate. The downstream gate is stricter on purpose; do not try to
   work around it. If the user gets impatient with the second prompt,
   explain that `/slack-post`'s gate is what guarantees nothing goes
   out without their literal go-ahead.

3. **Humanizer applies to drafted Slack output only.** Run it on the
   message body that will appear in the channel. Do not run it on the
   user's raw dictation, on internal reasoning, on summaries, or on
   anything not destined for Slack. Pre-mrkdwn-conversion is the right
   stage: humanizer first, then convert to Slack mrkdwn.

4. **Slack mrkdwn only for posted text.** Slack does not render
   CommonMark. The full conversion table lives in `/slack-post`'s
   SKILL.md (section "Slack mrkdwn reference"). Common gotchas:
   `*bold*` (not `**bold**`), `_italic_` (not `*italic*`), `<url|label>`
   (not `[label](url)`), no headings, no tables. `/slack-post` will
   reject things at the preview stage if you forget, but it's faster
   to produce mrkdwn from the start.

5. **Sequential processing.** One task at a time, end-to-end. Don't
   batch drafts. Don't open a second item before the current one is
   either posted, deferred, or skipped. Batching loses context and
   breaks the loop's "one decision, one outcome" rhythm.

6. **The user can pause, skip, or exit at any iteration.** Every
   prompt accepts those three as top-level options, not buried under
   "other".

## Phase 1: Todoist-anchored triage

### 1.1 Enumerate projects

Pull all projects, then split into three buckets:

- **Customer projects** — name matches `Kong-*` and is NOT `Kong-cs`.
  These run first, in whatever order the user specifies (or alphabetical
  if no preference).
- **Departmental** — `Kong-cs` only. Offered after customers as an
  optional second pass.
- **Other Kong projects** — name contains "Kong" but didn't match
  either bucket above (case-insensitive). Offered as an optional third
  pass.

```bash
td project list --json
```

Filter on the JSON output rather than relying on `--search`; it's cheap
and exact. Show the user the customer list before starting and ask if
they want to reorder.

### 1.2 Find tasks with Slack URLs

For each project in the active bucket:

```bash
td task list --project "<project-name>" --json
```

Scan each task's description for Slack URLs. If the description has
none, also check comments:

```bash
td comment list "<task-ref>"
```

Slack URLs in Todoist usually take one of these shapes:

- `https://<workspace>.slack.com/archives/<channel_id>/p<ts_no_dot>`
  — permalink to a top-level message
- `https://<workspace>.slack.com/archives/<channel_id>/p<reply_ts>?thread_ts=<thread_ts>&cid=<channel_id>`
  — reply in a thread
- `https://app.slack.com/client/<team_id>/<channel_id>/...`
  — app-style URL

To extract the pieces:

- **channel_id** is the segment after `/archives/` (or after `/client/<team_id>/`).
- **thread_ts**: prefer the `thread_ts` query parameter if present;
  otherwise the message ts itself is the thread root (insert a decimal
  before the last 6 digits: `p1709664532123456` becomes `1709664532.123456`).
- **workspace** comes from the subdomain — store it; you'll need it if
  there are multiple workspaces in `~/.config/slack/credentials.json`.

A task can carry multiple Slack URLs. Treat each unique
(channel_id, thread_ts) pair as a separate triage item, but group them
under the same task so the user gets a single "this task has 2 linked
threads" view. Most tasks will only have one.

If a task has no Slack URL, skip it. This skill is specifically about
Slack threads; tasks without thread links are out of scope.

### 1.3 Per-thread workflow

For each `(task, channel_id, thread_ts)` triple:

#### a. Read context

Pull the task and the thread:

- Task: `td task view "<task-ref>" --json` (status, due date, recent
  comments, who-changed-what)
- Thread: `slack_read_thread` (Slack MCP) with the resolved channel_id
  and thread_ts

For long threads (>20 messages), summarize the early portion mentally
and read the most recent ~10–15 messages in detail. The recent
messages are what determines whether action is needed.

While reading, identify:

- **The last person to post.** If it was the user, you're probably
  waiting on someone else. If it was someone else, the user might owe
  a reply.
- **The last open question.** Who asked, who hasn't answered, how long
  ago.
- **The thread's resolution state.** Is there a clear "done" message,
  or is it hanging?

#### b. Classify

Pick one:

- **needs-action** — someone is waiting on a substantive reply from
  the user. Examples: a customer asked a technical question, a
  teammate asked for a decision, a reviewer left feedback that needs
  a response. The reply will require new information from the user
  (their dictation).
- **needs-follow-up-ping** — the user previously asked a question or
  made an ask, and the other party hasn't responded. The right move
  is a short, light nudge — not a substantive reply.
- **no-action** — thread is at a natural pause, the ball isn't in the
  user's court, or the matter has been resolved elsewhere. Surface it
  so the user can confirm, then move on.

When in doubt, lean toward presenting it (with your guess) and letting
the user decide. False negatives (skipping something that needed
action) are worse than false positives (showing a thread that turns
out to be fine).

#### c. Present to the user

Show:

```
Task: <task title>  ←  <Todoist URL>
Thread: <Slack URL>   (open this to read in Slack natively)
Channel: #<channel-name>  (resolved via slack_search_channels)
Last message: <relative time> by <person>
Summary: <2–3 sentence state of the thread>
Suggested classification: <action | follow-up | no-action>
Why: <one-line reason>

Options: deal-now / defer / skip / pause
```

Keep the summary tight. If the user wants more, they'll click the
Slack URL. Always include the Slack URL on its own line so it's
clickable.

#### d. Branch on the user's choice

**defer** → ask: "leave it alone, or add a Todoist comment noting
you reviewed it today?" If comment:

```bash
td comment add "<task-ref>" --content "Reviewed 2026-05-07 — deferred."
```

(Use the actual current date.) Then move to the next item.

**skip** → no Todoist mutation, move to the next item.

**pause** → stop the loop, print a summary of what's been processed
and what's left, and exit. The user can resume by re-invoking the
skill; state is not persisted.

**deal-now** → proceed to step (e).

#### e. Compose the response

For **needs-follow-up-ping**:

Draft a short, light nudge. One or two lines, casual register. Don't
over-engineer it. Examples (these are not templates to use literally):

- *"hey @person, bumping this — any thoughts when you get a sec?"*
- *"following up on this one, lmk if anything's blocking"*

Run through `humanizer`. Convert to Slack mrkdwn (resolve `@person` to
`<@U_ID>` via `slack_search_users` if you don't already have the ID).
Show the rendered draft to the user along with the target channel/thread.

For **needs-action**:

Ask the user to dictate the substantive content: "What's the
information you want to send back?" Wait for their answer. They might
type a short note, paste a link, or talk through what they want
covered.

Compose the message based on their dictation. Match the depth and
register of the thread you read in step (a) — a casual teammate
thread gets a casual reply; a customer escalation thread gets a
careful, structured one. Do NOT pad with filler. Do NOT add
unsolicited recommendations or extra context the user didn't mention.
Your job is to render their thinking cleanly, not to expand it.

Run through `humanizer`. Convert to Slack mrkdwn. Show the rendered
draft to the user.

#### f. First approval gate (light)

Show the draft verbatim, exactly as it will be passed to `/slack-post`.
Include a header line like:

```
DRAFT for #<channel> (thread by <person>, <date>):
---
<the message body>
---
Approve? (yes / edit / cancel)
```

Accept any clear yes. If the user wants edits, take them and re-show.
If the user cancels, treat as skip.

#### g. Hand off to `/slack-post`

Invoke the `/slack-post` skill. Pass it:

- The channel ID (`C...` for public, `G...` for private, `D...` for DM)
- The thread_ts
- The drafted body

`/slack-post`'s skill will run its own humanizer pass (idempotent — no
harm done if it re-checks already-clean text), em-dash scrub, mrkdwn
verification, and preview. It will then ask the user for an explicit
"send" / "ship it" / "post it" / "yes send" before adding `--send`.
Do not interfere with that flow. Specifically, do NOT pre-add `--send`
on the user's behalf; let `/slack-post` ask its own question.

If the user's response to `/slack-post`'s prompt is fuzzy ("looks
good", "ok"), `/slack-post` will re-confirm. Let it. That second gate
is the load-bearing one.

#### h. Confirm and record

After a successful send, `/slack-post` prints a permalink on stdout.
Surface it to the user verbatim, on its own line so it's clickable:

```
Posted ✓  https://<workspace>.slack.com/archives/.../p1709664532123456
```

(The check mark there is fine — that's not the message body.)

Optionally offer to add a Todoist comment recording the post:

```bash
td comment add "<task-ref>" --content "Replied via Slack: <permalink>"
```

Ask before doing this — some users prefer the Todoist task to stay
clean and rely on Slack history. If unsure, default to NOT adding the
comment unless the user has previously said they want them.

Move to the next item.

### 1.4 Phase 1 wrap-up

When all customer projects are done, summarize:

```
Phase 1 customer pass: <N> items processed
  posted: <count>   deferred: <count>   skipped: <count>   no-action: <count>

Continue to Kong-cs (departmental)? (yes/no)
```

If yes, run the same loop on `Kong-cs`.

Then ask:

```
Process other Kong projects (anything with "Kong" in the name not
already covered)? (yes/no)
```

If yes, list them and ask the user to confirm or trim the set, then
loop.

## Phase 2: Slack-anchored sweep (optional)

After Phase 1, ask:

```
Phase 1 done. Want to sweep your Slack activity from the last 2 weeks
for threads not already covered in Todoist? (yes/no)
```

If no, exit with the Phase 1 summary.

If yes:

### 2.1 Resolve the user's own Slack ID

```
slack_search_users (Slack MCP) — query by name or email
```

Cache the user_id for later filtering. The user's email is in the
session context (`dustin@bashfulrobot.com`) if the search-by-name is
ambiguous.

### 2.2 Search recent activity

Use `slack_search_public_and_private` with a query that pulls messages
the user posted in the last 14 days:

```
from:@<username> after:<YYYY-MM-DD>
```

(Resolve `<username>` from the user_id if needed; Slack search uses the
display handle, not the U_ID, in the `from:` operator.)

This gets messages the user posted. For each result, extract
`channel_id` and `ts`. To get the thread root for each message:

- If the result message has a `thread_ts` distinct from its `ts`,
  that's the thread root.
- Otherwise the message itself is the thread root (it could be a
  parent or a standalone message; treat it as a thread root for triage
  purposes).

### 2.3 Dedupe against Phase 1

Build a set of `(channel_id, thread_ts)` pairs from every Slack URL
processed in Phase 1. Drop any candidate whose pair is in that set.

### 2.4 Present a candidate list

Show a compact list:

```
Found <N> threads not in Todoist. Pick which to drill into:

  1. #cust-acme   "deck draft for Q3 EBR..."   2 days ago
  2. #cust-globex "ratelimit plugin question"  4 days ago
  3. DM with @sarah  "hey re the kong mesh trial..."  6 days ago
  ...

Which (e.g. "1,3,5–7" or "all" or "none")?
```

This gate prevents the loop from churning through dozens of trivial
threads. The user picks the subset that actually matters.

### 2.5 Loop the chosen subset

For each chosen thread, run the same per-thread workflow as Phase 1
section 1.3, starting from step (a). The only difference is there's no
Todoist task to mutate on defer; if the user defers and wants a
record, offer to create a new Todoist task instead:

```bash
td task quickadd "Follow up on Slack thread <permalink> #Kong-<customer>"
```

Ask which project to put it in (default to the customer project if
the channel name maps to one obviously, otherwise ask).

### 2.6 Phase 2 wrap-up

Summarize and exit, same shape as Phase 1.

## Tone calibration

Match the thread, not a template:

- **Customer threads** — careful, structured, no slang. Signal you've
  read the thread (reference the specific question or artifact). Never
  over-promise. Default to Canadian English spellings.
- **Internal teammate threads** — casual, direct, can use lowercase
  starts. Drop fluff.
- **Follow-up pings** — always short. One line is fine. Two is
  plenty.

The user's `writing-style` skill (if present) captures their voice
across registers; defer to it after `humanizer`. The combined
pipeline is: draft → `humanizer` → `writing-style` → mrkdwn convert →
preview.

Don't add closings ("Thanks!", "Cheers,", etc.) inside thread replies
unless the surrounding thread has them. Most Slack threads don't need
sign-offs; they're conversational.

## Error handling

- **`td` returns an empty project list** — auth probably expired. Tell
  the user to run `td auth login` and abort.
- **Slack MCP read fails** — surface the error and ask whether to skip
  this thread or retry. Don't silently move on; the user might want
  to handle that one manually in the Slack app.
- **`/slack-post` script errors** — relay the script's stderr verbatim
  and abort the post. Common causes: stale xoxc/xoxd token (fix:
  `slack-token-refresh`), wrong workspace key, channel ID typo.
- **Channel ID resolution fails** — happens when a Slack URL points to
  a channel the user no longer has access to. Skip with a note; do not
  attempt to post.

Never invent IDs. Always resolve from the Slack URL or via MCP search.
A typo'd channel ID could send to the wrong place.

## What to write down (per item) while running

Keep an in-conversation ledger for the summary at the end:

```
[1] Kong-acme: "Q3 EBR deck review" — posted (https://...)
[2] Kong-acme: "ratelimit followup"  — deferred (commented)
[3] Kong-globex: "trial start date"  — skipped
[4] Kong-cs:  "internal sync notes"  — no-action
...
```

This is just context for the wrap-up summary; nothing persists across
sessions.

## What this skill does NOT do

- Does NOT post to Slack via the MCP. Ever.
- Does NOT mutate Slack state (no reactions, no edits, no deletes).
- Does NOT auto-complete Todoist tasks. Posting a reply doesn't mean
  the underlying work is done; the user closes their own tasks.
- Does NOT cross sessions. State is conversation-local; if the user
  pauses and resumes later, they re-enumerate.
- Does NOT batch posts. One draft, one approval, one send, one
  permalink, then the next item.

## Quick reference — Slack MCP tools allowed in this skill

Read-only:

- `slack_search_users` — resolve a username/email to a U_ID
- `slack_search_channels` — resolve a channel name to a C_ID
- `slack_search_public_and_private` — find recent messages (Phase 2)
- `slack_read_thread` — read a thread by C_ID + thread_ts
- `slack_read_channel` — fall-back when a thread read isn't enough
- `slack_read_user_profile` — get name/title for a U_ID

Forbidden in this skill:

- `slack_send_message`
- `slack_send_message_draft`
- `slack_schedule_message`
- `slack_create_canvas`, `slack_update_canvas` (out of scope; not
  forbidden in general)

The send-equivalent in this skill is always the `/slack-post` skill.
