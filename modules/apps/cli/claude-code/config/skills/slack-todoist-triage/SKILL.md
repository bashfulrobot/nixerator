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

3. **Humanizer runs on every text Claude generates that persists
   under the user's identity.** That includes Slack message bodies,
   Todoist comment bodies, Todoist task content/descriptions, and
   any other artefact saved into a system as the user. Even when the
   source is the user's own dictation, Claude is still producing the
   final string — em-dashes, rule of three, vague attributions, and
   other AI-tells creep in during transcription and paraphrase, and
   they're attributable to the user once they land in the system.

   Humanizer does NOT run on: internal reasoning, the skill's own
   summaries shown to the user in conversation, or classification
   recommendations.

   Pipeline order for any generated output that persists under the
   user's identity:

   ```
   draft → humanizer → writing-style (if applicable) → surface-specific
   formatting (Slack mrkdwn / Todoist Markdown / etc.) → preview
   ```

   `/slack-post` enforces this for Slack outputs already; Todoist
   writes from this skill must do the same explicitly.

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

7. **Every URL is a labelled link in the right syntax for its
   surface, never a bare URL or raw ID.** Future-them (or the thread
   reader) won't recognize `C070FKK6GBT` or `p1777500663216049` —
   they'll recognize "the primary Slack thread" or "FTI-7504". Pick
   a label from what they're most likely to identify the artefact
   by: the channel topic, the customer name, the ticket title, the
   person who posted, the artefact's purpose. Then format with the
   syntax of the destination:

   | Surface | Syntax | Example |
   |---|---|---|
   | Todoist (CommonMark) | `[label](URL)` | `[primary Slack thread](https://...)` |
   | Slack (mrkdwn) | `<URL\|label>` | `<https://...\|primary Slack thread>` |

   Slack mrkdwn `<URL|label>` is *not* the same as CommonMark — Slack
   does not render `[label](URL)`. Convert at draft time, before
   handing to `/slack-post`. Bare URLs are technically auto-linked
   in Slack, but labeled links are clearer and let future readers
   skim the message without parsing URLs visually.

   This rule applies to every Todoist write (`td comment add`,
   `td comment update`, `td task quickadd`, `td task add`) and every
   Slack draft this skill produces. Raw IDs and bare permalinks in
   user-facing text are a defect.

8. **Every draft preview shown to the user names its destination
   explicitly.** Before showing any draft body — Slack message,
   Todoist comment, Todoist task, or anything else this skill might
   write somewhere — lead with a one-line header that identifies
   exactly where the content will end up. The user is approving
   not just the text but the routing; ambiguity about destination
   is how a customer-thread reply ends up on a personal task or
   vice versa.

   Required components in every draft header:

   - The system (Slack, Todoist, etc.)
   - The container (channel name, task title, project name)
   - The specific destination (thread permalink, task URL, comment
     target) when one applies
   - The action (post, comment, create, update)

   Examples (adapt the wording, but keep all four components):

   ```
   DRAFT — Slack reply to <#channel-name> thread (started by <person>
   on <date>) in workspace <workspace>:
   ```

   ```
   DRAFT — Todoist comment on task "<title>" (<Todoist task URL>):
   ```

   ```
   DRAFT — new Todoist task in project <Kong-customer>, section <X>:
   ```

   The destination header replaces ambiguous phrasing like "here's
   the draft" or just dumping the body in a code block. If the
   user can't tell where the content is going from the header
   alone, the header isn't doing its job.

## Step 0 — Establish point of view (run once per session)

The triage loop runs from a specific user's perspective: their tasks,
their threads, their voice. Before any project enumeration or thread
reading, anchor whose POV "the user" refers to in this session. This
matters for:

- Detecting "your last post" in a thread — match on `user_id`, never
  on display-name string matching (display names drift, get reused
  across people, and may not match Todoist's record).
- Phase 2 search filtering — `from:@<username>` needs the right
  handle.
- Drafting tone — the reply will go out in this person's voice, so
  names, pronouns, and sign-offs need to be theirs.
- Confirming the right Slack workspace if `~/.config/slack/credentials.json`
  carries credentials for more than one.

Resolve the current authenticated Slack user via the MCP.
`slack_read_user_profile` with no `user_id` argument returns the
profile of the current session user — that's the right anchor.

Capture and cache for the session:

- display name (e.g., "Dustin Krysak")
- user_id (e.g., `U0962HABY84`)
- primary email (cross-checks against Todoist)
- workspace handle (from `~/.config/slack/credentials.json` or the
  Slack URL subdomain — e.g. `kongstrong`)

Then **announce** the resolved identity as a one-liner — do not ask
the user to confirm. The lookup is authoritative for the
authenticated session; asking adds ceremony for a thing that's
correct nearly every time.

```
Running as <Name> (<user_id>) on workspace <handle>.
```

The user can correct it inline if something looks wrong (e.g., they
have multiple Slack accounts and want a different one). Cache for
the rest of the session; do not re-announce.

Two caveats that DO warrant a prompt:

1. **Lookup mismatch.** If the lookup result conflicts with known
   context — e.g., user-memory or `CLAUDE.md` says the user is
   "Alice" but the Slack profile returns "Bob" — flag it explicitly:

   ```
   Heads up: Slack returned <Bob> but I expected <Alice> from your
   memory/CLAUDE.md. Use Slack's identity, switch to <Alice>, or abort?
   ```

2. **Lookup failure.** If `slack_read_user_profile` fails (auth, MCP
   unavailable, ambiguous result), abort the skill and surface the
   error. Running without an anchored POV is unsafe — the loop could
   misclassify who posted last in a thread, draft from the wrong
   voice, or search for the wrong activity in Phase 2.

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

Scan each task's **content** (the task title) AND **description** for
Slack URLs. The user routinely embeds Slack URLs in task titles via
Markdown link syntax (e.g., `[topic](https://...slack.com/archives/...)`),
so scanning description alone misses the majority of triageable tasks.
A `jq` pattern that catches both:

```bash
td task list --project "<project-name>" --json \
  | jq -r '.results[]? | select(((.content // "") + " " + (.description // "")) | test("slack\\.com")) | .id'
```

If neither content nor description has a Slack URL, fall back to
comments:

```bash
td comment list "<task-ref>"
```

Tasks that don't surface a Slack URL via any of these three are out
of scope for this skill.

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

### 1.2-bis Default scope filter

The full set of Slack-linked tasks in a Kong-* project can be very
large — backlog references, already-resolved threads, low-priority
reminders. Walking all of them every pass exhausts the user and
trains the loop into low signal. By default, narrow each project's
set using two signals the user has already encoded in Todoist:

- **Priority is p1, p2, or p3.** The user's own assessment of
  importance. p4 (Todoist's default for un-prioritized tasks) is
  treated as backlog.
- **OR due date is set and falls in: overdue, today, or the next 14
  days.** The user's own scheduling signal.

OR semantics, not AND. A p1 with no date is in. A p4 that's overdue
is in. A p4 with no date is out.

The Todoist API priority is inverted from the user-facing label:
API 4 = p1 (highest), API 1 = p4 (lowest). Filter on
`.priority >= 2` to include p1-p3.

A jq pattern that combines the Slack-URL filter from 1.2 with the
default scope filter:

```bash
upper=$(($(date -u +%s) + 14*86400))

td task list --project "<project-name>" --json | jq -r --argjson upper "$upper" '
  .results[]?
  | select(((.content // "") + " " + (.description // "")) | test("slack\\.com"))
  | select(
      (.priority >= 2)
      or (
        (.due.date // null) != null
        and (.due.date + "T00:00:00Z" | fromdateiso8601) <= $upper
      )
    )
  | "\(.id)\t\(.content)"
'
```

#### Per-project count surface

Before walking a project, surface the filter outcome so the user can
see what's in vs. out:

```
Kong-<customer>: <N> Slack-linked tasks total
  in scope (p1-p3 or upcoming/overdue): <M>
  dropped (p4 with no near-term date): <K>

Process default scope, expand to all, or skip this project?
(default / all / skip)
```

#### Overrides

Three options at each project boundary:

- **default** — walk only tasks matching the scope filter
- **all** — walk every Slack-linked task in the project, ignore the
  filter for this project
- **skip** — skip the whole project this session

#### Session-wide scope

If the user pre-declares a scope at the start of Phase 1 ("just p1
today", "everything", "due within a week", "today only"), apply that
to all subsequent projects without re-asking the per-project override
question. Surface the active scope in each project's count line so
the user can see what filter is in effect.

Examples of session-wide scope translations:

- "just p1 today" → `.priority == 4` (API) AND due is today or
  overdue
- "everything" → no filter beyond the Slack-URL test
- "due within a week" → `.due.date` exists and is within 7 days
- "today only" → `.due.date` is today (or overdue, depending on
  user intent — confirm if ambiguous)

When in doubt about what a session-wide scope means, ask the user
once at the start; don't infer silently.

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

#### a-bis. Cross-references in the thread

While reading the primary thread, scan every message body for
additional Slack URLs (`*.slack.com/archives/...`). These cross-
references usually mean the conversation moved elsewhere, someone
linked a related ticket, or the same workstream forked into a parallel
thread. They're often where the actual current state lives — easy to
miss otherwise.

For each unique cross-link found, follow it once (one
`slack_read_thread` call) — but do **not** recurse: don't follow
cross-links found inside the cross-linked threads. That's a rabbit
hole. Cap auto-follow at the first 3 unique cross-references; surface
the rest as URLs only with a note ("N further cross-references not
auto-followed").

Skip cross-links that point to a different message within the same
thread (those are usually anchor jumps; channel_id and thread_ts
match the parent).

Dedupe against threads already enumerated in this session — both
prior Phase 1 tasks and any Phase 2 candidate list. If a cross-link
matches one, mark it as already-covered and move on.

Surface cross-link info in the presentation as a "Related threads"
addendum, regardless of the include/fold/ignore decision the user
makes — the URL and a one-line topic are useful context even if no
action is taken:

```
Related threads (followed, depth 1):
  → <url>
    Last activity: <relative time> by <person>
    Topic: <1–2 line summary>
```

After the standard classification options for the primary thread, ask
once per related thread whether to:

- **include** it as a separate triage item this session
- **fold** its context into the current item's draft (appropriate
  when the cross-link is clearly a continuation of the same
  conversation, e.g. same customer, same topic, recent activity)
- **ignore** it (mention in the wrap-up summary, take no action)

Default to ignore when in doubt. Folding suits continuations;
including suits cases where the cross-link is a separate but related
ask the user should also handle. The user can change their mind by
responding with a different choice.

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
Channel: #<channel-name>  (or "channel <ID>" if name not resolvable)
Last message: <relative time> by <person>
Summary: <2–3 sentence state of the thread>

Related threads (followed, depth 1):  [omit section if none]
  → <url>
    Last activity: <relative time> by <person>
    Topic: <1–2 line summary>

Suggested classification: <action | follow-up | no-action>
Why: <one-line reason>
Action shape: <see "Action shape" below>

Options: deal-now / defer / skip / pause
```

Keep the summary tight. If the user wants more, they'll click the
Slack URL. Always include the Slack URL on its own line so it's
clickable.

**Channel name resolution caveat.** `slack_search_channels` searches
by name keywords (e.g., "lululemon", "paypal", topic terms), not by
channel ID. A query like `slack_search_channels(query="C070FKK6GBT")`
returns nothing. When you don't already know a name keyword, infer
one from context (the customer name from the Todoist project — e.g.
`Kong-lululemon` → query `lululemon`), and fall back to "channel
<ID>" in the presentation if no match comes back. Don't fabricate a
name. The Slack URL is the source of truth either way.

##### Action shape — articulate the lift before the user decides

Before the user commits to deal-now vs. defer vs. skip, they need to
know what the actual work would be. The "Action shape" line answers
"what would dealing with this look like, and is any action even
recommended?" Pick the one that fits and state it plainly:

- **No new information needed** — you can draft a reply from existing
  thread context (and any cross-references already read). When this
  is the shape, also offer 2–3 framing variants the user can pick
  from, e.g. light status-check / directive push / pointed
  escalation. Don't pick the framing silently; the voice and pressure
  are the user's call.
- **Needs dictation** — the response requires substantive new
  content the user has to provide (a technical answer, a decision, a
  next step). State what kind of input you're going to ask for so the
  user knows whether they have it ready.
- **Needs offline verification first** — the user has to go check
  something (look at a dashboard, ping a customer, read a doc) before
  any reply is meaningful. The natural choice in this case is `defer`
  with a note; flag that explicitly so the user doesn't burn a deal-
  now slot on something they can't actually answer yet.
- **No action recommended** — the thread has reached a natural
  conclusion: it was answered, the ball isn't in the user's court, or
  the matter has been resolved elsewhere (often visible via the
  cross-references). Say so directly. Do NOT soften it with hedges
  like "probably worth a quick check" — surfacing a no-op is just as
  valuable as a posted reply, and it saves the user time.

Threads do reach natural conclusions. When that's the case, the
honest read is the most useful one. The user will either confirm
(treat as no-action, log accordingly) or override ("actually I do
want to ping") — both are fine.

When you classify as `no-action`, the natural user response is to
confirm (which logs as no-action in the running ledger) or to
override into deal-now. Treat `skip` and `no-action confirmed` as
distinct in the wrap-up summary so the user can see the difference
between "I chose to ignore that one" and "we agreed nothing was
needed."

##### Mid-flow reclassification

User input often changes the picture mid-decision. They share a
meeting they had, mention a parallel thread, name a person who's the
actual blocker, or provide context that flips the suggested
classification ("actually that's already resolved — the conversation
moved to DM", "wait, this is going to need a real escalation").

When this happens:

1. Acknowledge briefly that the new info changes the read.
2. Re-state the classification with updated reasoning — say what
   moved and why.
3. Re-present the Action shape and options. Do not silently roll
   forward on the original recommendation; the user shouldn't have
   to remember to pull you back.

This is also the natural moment to offer a context-note capture (see
the cross-cutting capture step) — the new info is exactly the
side-channel context worth recording on the task.

#### d. Branch on the user's choice

**defer** → if a context note was already captured this item (per
the cross-cutting capture step), treat it as the review record and
move to the next item. Do not ask for a redundant "deferred" stamp;
two comments saying "we looked at this today" is noise.

If no context note was captured, ask: "leave it alone, or add a
Todoist comment noting you reviewed it today?" If yes:

```bash
td comment add "<task-ref>" --content "Reviewed 2026-05-07 — deferred."
```

(Use the actual current date.) Hard rule 7 doesn't apply here —
there's no URL to label, so plain text is fine. Then move to the
next item.

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
Lead with a destination header per hard rule 8:

```
DRAFT — Slack reply to #<channel-name> thread (started by <person>
on <date>) in workspace <workspace>:
---
<the message body>
---
Approve? (yes / edit / cancel)
```

If the draft contains any Slack mrkdwn — user mentions (`<@U...>`),
channel links (`<#C...>`), labelled URLs (`<URL|label>`), `*bold*`,
`_italic_`, code blocks — append a one-line note under the preview
explaining that the syntax is correct as shown and will render
properly when Slack receives it. The terminal can't show Slack's
rendered output, so without that note the user might mistake the raw
mrkdwn for an error. Example note (keep it short, one line):

```
(Mrkdwn note: the <@U...> mention and <URL|label> links render
correctly in Slack — this preview shows the raw syntax that gets
sent.)
```

Tailor the note to whatever's actually in the draft. If the draft is
plain prose with no mrkdwn-rendered elements, skip the note —
overhead for nothing.

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

#### Cross-cutting: capture user context as Todoist comments

Throughout the workflow, the user often shares side-channel context
that didn't come from the Slack thread or the Todoist task: meetings
they've had, parallel conversations, customer-relationship signals,
strategic framing, what's actually blocking, what's being said
elsewhere. This context is valuable to future-them when they revisit
the task. Currently it's lost the moment the session ends.

When the user provides substantive context that goes beyond a
procedural answer (`deal-now`, `defer`, `yes`, etc.), offer to
capture it as a Todoist comment on the relevant task. The trigger is
fuzzy — any time the user adds knowledge to the situation, it's a
candidate. Examples that should trigger an offer:

- "I had a meeting with them yesterday and they're ready to escalate"
- "this has been discussed in three other threads"
- "they're stuck on the 60K RPS number because of contract language"
- "Lulu's CSAT is dropping fast"
- "internal feedback on this has been positive"

Examples that should NOT trigger:

- procedural answers (`deal-now`, `yes`, `skip`, `defer`, `fold`)
- the user agreeing with a recommendation without adding new info
- the skill's own summaries (already derivable, would be noise)

##### When to prompt for a comment (workflow moments)

User-volunteered context isn't the only time to offer a capture.
Several decision points in the loop are natural moments to ask
explicitly. Don't skip these — silent transitions lose information.

| Workflow moment | Prompt? | Reason |
|---|---|---|
| User volunteers side-channel context (any step) | Always offer | The trigger above; this is the primary case. |
| Cross-link read reveals important state user didn't articulate | Always offer | The cross-link's content (e.g., "the AA issue was internal-only") may be the most valuable thing learned this session; capture even if the user doesn't surface it. |
| User chooses `skip` with a reason ("Declan owns this") | Offer | The reason is the gold; without it, future-them can't tell why we skipped. |
| User confirms `no-action` (suggested or volunteered) | Offer | "Thread reached natural conclusion via DM with X" is exactly what future-them needs to not re-triage this. |
| User chooses `defer` | Conditional | If a context note was already captured this item, treat that as the review record; don't ask again. If not, offer the lighter "Reviewed YYYY-MM-DD — deferred" stamp. |
| Compose stage produces reasoning that won't fit in the Slack reply | Offer | Sometimes the dictation contains strategic context (why we're framing it this way) that's worth recording on the task even if it doesn't go to Slack. |
| After a successful Slack post | Conditional | Offer the "Replied via [Slack thread](permalink) on YYYY-MM-DD" link by default; default to NO unless the user has previously said they want them, since post permalinks are also visible in Slack history. |
| User chooses `pause` mid-loop | Always offer per pending item | Pausing without capturing what we learned about the in-flight item discards work. |
| Procedural answers only (`yes`, `skip`, `deal-now`) | Don't prompt | Pure flow control; nothing to capture. |

When in doubt, lean toward offering — the user can always say no, and
the cost of an extra prompt is much lower than the cost of losing
context that future-them needs.

Always ask before writing. Show the proposed comment with a
destination header per hard rule 8:

```
DRAFT — Todoist comment on task "<title>" (<Todoist task URL>):

<comment body — first person, casual, no scaffolding>

(yes / edit / no)
```

Format conventions:

- **Write as the user.** First person, casual register, no scaffolding
  or prefix. These are notes-to-self the user is dropping between
  meetings, not formal triage records. No "Context note YYYY-MM-DD
  (triage):" header, no role labels, no ceremony. Todoist already
  timestamps comments at creation, so a date prefix in the body is
  redundant. The comment should read like the user typed it
  themselves on their phone in 30 seconds.
- Run through `humanizer` per hard rule 3. Even when transcribing the
  user's dictation, Claude is producing the final text and can
  introduce AI-tells (em-dashes, rule of three, vague attributions,
  promotional adjectives). Humanizer catches those; running it on
  naturally-human text is a no-op, so there's no downside.
- Apply `writing-style` after humanizer if the skill is present — it
  captures Dustin's voice across registers (Canadian English,
  casual/professional split). For Todoist notes-to-self, the casual
  register applies (lowercase starts are fine, contractions, terse
  phrasing, no formality).
- This is an internal note, not customer-facing. No closings, no
  greetings, no signoffs. Just the substance.
- Multi-line is fine.
- Don't paraphrase to the point of summarization. Light cleanup
  (collapsing "uh" / fragments / typos) is fine; rewriting the
  thought isn't.
- **Use Markdown links for every URL-addressable reference. Never
  paste raw channel IDs, user IDs, or message timestamps as text.**
  Todoist renders Markdown in comments and descriptions, so write
  `[primary Slack thread](https://workspace.slack.com/archives/.../p123)`
  not `channel C070FKK6GBT`. Same goes for Jira tickets
  (`[FTI-7504](https://konghq.atlassian.net/browse/FTI-7504)`),
  cross-linked threads (`[cross-link from <person>](url)`), and any
  other artefact the user might want to click through to. Future-
  them is reading this comment 3 weeks from now without context — a
  raw ID tells them nothing; a labelled link is one click to the
  source.
- Choose the link label by what the user is most likely to recognize:
  the channel topic, the customer name, the ticket title, the
  person who posted. "the primary Slack thread", "the cross-link
  from David", "[FTI-7504]" all beat "C070FKK6GBT" or "p17776...".

On approval, post via `td comment add` and immediately surface the
resulting comment URL so the user can click through to verify
exactly what landed in Todoist. Use `--json` to extract the new
comment ID reliably, then build the deep-link URL by combining it
with the parent task ID:

```bash
new_id=$(td comment add "id:<task-id>" --content "<first-person note>" --json | jq -r '.id')
echo "Comment added: https://app.todoist.com/app/task/<task-id>#comment-${new_id}"
```

Then surface the URL to the user verbatim, on its own line so it's
clickable:

```
Comment added ✓  https://app.todoist.com/app/task/<task-id>#comment-<comment-id>
```

Apply the same URL-surfacing pattern to every Todoist write the
skill performs — the post-confirm comment in step 1.3.h, the
deferred stamp in step 1.3.d (when one is added), and the new-task
creation in Phase 2.5. The user shouldn't have to dig through
Todoist to verify what was written; a clickable link returns
confirmation in one click.

Capture before posting any Slack reply. The capture is independent of
the deal-now/defer/skip outcome — context is worth recording even on
items the user defers or skips. A skipped task with a captured
"context note" is far more useful next session than a skipped task
with no record.

In Phase 2 there's no Todoist task to attach to (the thread came from
the Slack sweep, not from Todoist). If the user provides substantive
context during Phase 2, the natural move is to offer to create a new
Todoist task seeded with the context — see Phase 2.5 for the
`td task quickadd` pattern.

#### h. Confirm and record

After a successful send, `/slack-post` prints a permalink on stdout.
Surface it to the user verbatim, on its own line so it's clickable:

```
Posted ✓  https://<workspace>.slack.com/archives/.../p1709664532123456
```

(The check mark there is fine — that's not the message body.)

Optionally offer to add a Todoist comment recording the post. Use a
Markdown link for the permalink (per hard rule 7):

```bash
td comment add "<task-ref>" --content "Replied via [Slack thread](<permalink>) on 2026-05-07."
```

Pick a label that gives future-them a hint of where the reply went —
`[Slack thread](...)`, `[reply to <person>](...)`, or `[<channel topic>](...)`.
Never paste the raw permalink as text.

Ask before doing this — some users prefer the Todoist task to stay
clean and rely on Slack history. If unsure, default to NOT adding the
comment unless the user has previously said they want them.

Move to the next item.

### 1.4 Phase 1 wrap-up

When all customer projects are done, summarize:

```
Phase 1 customer pass: <N> items processed
  posted: <count>   deferred: <count>   skipped: <count>   no-action: <count>

Out of scope (per default filter): <total> tasks across <P> projects
```

#### Optional: explore dropped

Before moving on, offer a final pass over the tasks that the default
scope filter dropped — they're easy to forget about and some may have
live Slack activity worth a glance:

```
Want to explore the dropped tasks? (yes / no)
```

If yes, show a per-project breakdown:

```
Dropped tasks by project:
  Kong-paypal: 4
  Kong-sony: 12
  Kong-zillow: 3
  ...

Pick a project to walk, or "skip" to move on.
```

If the user picks a project, walk its dropped tasks the same way as
1.3. If "skip", proceed.

#### Continue or wrap

```
Continue to Kong-cs (departmental)? (yes/no)
```

If yes, run the same loop on `Kong-cs` (apply the same default scope
filter unless overridden).

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
record, offer to create a new Todoist task instead. Per hard rule 7,
the permalink goes in as a labelled Markdown link, never bare:

```bash
td task quickadd "Follow up on [Slack thread with <person>](<permalink>) #Kong-<customer>"
```

Pick a task title that gives future-them enough hint to recognize it
without clicking through — the customer name, the topic, or the
counterparty. The Markdown link inside the quickadd renders as a
clickable label in the resulting task. Ask which project to put it in
(default to the customer project if the channel name maps to one
obviously, otherwise ask).

### 2.6 Phase 2 wrap-up

Summarize and exit, same shape as Phase 1.

## Tone calibration

Match the thread, not a template:

- **Customer threads** — careful, structured, no slang. Signal you've
  read the thread (reference the specific question or artifact). Never
  over-promise. Default to Canadian English spellings.
- **Internal teammate threads** — casual, direct, drop fluff. The
  user's casual style allows a lowercase first word as a casual
  message-opener (`hey`, `for sure`, `yeah`, `quick update`), but
  this is *opener-only*: every subsequent sentence in the same
  message follows normal capitalization. A multi-sentence draft like
  `hey, quick update. the call hasn't happened yet. will come back...`
  reads as sloppy or AI-flat — the right form is `hey, quick update.
  The call hasn't happened yet. Will come back...`. Lowercase the
  first word at most; capitalize after periods like a normal human
  would.
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
