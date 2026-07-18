# Assessment schema, digest, and actions

The fixed contract for a Phase-1 result, plus how a batch of results is grouped
into a digest and what Phase-2 actions are allowed. Keeping the schema fixed is
what lets results from independent subagents collate into one digest.

> **Wizard note.** The default walk renders a pure-state card and does NOT produce
> a recommendation. The recommendation fields below (`next_action`, `action_type`,
> `draft_ready`, `draft`) are used ONLY when `dig` invokes a research subagent —
> they carry that subagent's structured findings. The state fields
> (`what_it_is`, `status`, `ball_owner`, `days_silent`, `current_column`,
> `recommended_column`, `recent_context`, `unverified`, `sources`) are what the
> card and the auto-move consume. The card's derived triad (Ball / Where it stands
> / Next) is built from `ball_owner` + `days_silent` + `recent_context` + the last
> recorded next-step in the log; the "Next" line is extracted from the log, never
> invented.

## Per-task result schema

Every subagent returns exactly this object (JSON). No extra top-level keys —
extra keys break collation and the digest builder.

```json
{
  "task_id": "8Jx4mVr72kPn3QwB",
  "title": "Follow up with lululemon on mTLS rollout",
  "project": "Kong-lululemon",
  "due": "2026-07-10",
  "priority": "p1",
  "current_column": "Up Next",
  "recommended_column": "Waiting Customer",
  "what_it_is": "One or two sentences: what this task actually is, in plain terms.",
  "status": "waiting-on-them",
  "ball_owner": "them",
  "days_silent": 12,
  "next_action": "Nudge Priya on the mTLS cert bundle she owed on 2026-06-28.",
  "action_type": "email",
  "draft_ready": true,
  "draft": "Hi Priya, following up on the mTLS cert bundle...",
  "confidence": "high",
  "sources": [
    {"source": "todoist", "citation": "task comment 2026-06-20: 'waiting on Priya for cert bundle'"},
    {"source": "gmail", "citation": "thread 'mTLS bundle' — last msg from Dustin 2026-06-28, no reply since"}
  ],
  "recent_context": [
    {"source": "gmail", "who": "Dustin", "when": "2026-06-28", "excerpt": "Following up on the cert bundle — can you send the PEM when you get a sec?"},
    {"source": "slack", "who": "Priya", "when": "2026-06-20", "excerpt": "on it, should have it to you early next week"}
  ],
  "unverified": ["Freshservice FS-4471 state — no API; task claims it's still open"]
}
```

### Field rules

- **`status`** — one of: `on-track` · `waiting-on-them` · `waiting-on-me` ·
  `blocked` · `stale` · `likely-done` · `wrong-or-stale-reference`.
- **`ball_owner`** — `them` · `me` · `nobody` (nothing to do / done) · `unknown`.
  Derive from the freshest real signal (last thread reply, last Slack message,
  last comment), **not** from the due date.
- **`days_silent`** — integer days since that freshest signal. This plus
  `ball_owner` is the primary triage sort key.
- **`action_type`** — the Phase-2 **verb**, so the digest line reads as a
  pre-filled macro rather than prose. One of: `note` · `defer` · `move` ·
  `reprioritize` · `complete` · `drop` · `close-into` · `merge` · `send` ·
  `teams` · `email` · `correct-reference` · `none`. These map 1:1 to
  `references/macros.md`; if you find yourself wanting a verb that isn't there,
  the answer is `none` plus a `next_action` explaining why, not an invented verb.
- **`current_column` / `recommended_column`** — for tasks on a `Kong*` board
  project only (others have no sections; use `null`). `current_column` is where
  the task sits now; `recommended_column` is where the assessment says it belongs,
  per the routing table in `references/kanban-board.md`. When they differ, that
  mismatch is a triage signal — the `move` verb acts on it. When they match, or
  when the right column is genuinely unclear, set `recommended_column` equal to
  `current_column` (no move) rather than guessing.
- **`draft_ready`** — `true` only if the subagent has enough to prepare the draft
  without more research.
- **`draft`** — the humanized message text, present **only** when `draft_ready`
  is true and `action_type` is an outward verb (`send`/`teams`/`email`). The
  subagent writes it during assessment so Phase 2 collapses to preview then send
  instead of a second research-and-draft round trip. Composing text is not a
  write, so this respects Phase 1's read-only rule. **Run it through `humanizer`
  before returning it** (customer-facing → `writing-style`); an unhumanized draft
  is worse than none, because it looks ready and isn't. The draft is
  *provisional*: it does not shorten the mandatory preview or the explicit-send
  gate. Omit for internal verbs.
- **`confidence`** — `high` · `medium` · `low`. A low-confidence read is still
  worth surfacing; just label it.
- **`sources[]`** — one entry per source consulted, each with a **concrete**
  citation (thread subject + date, comment date, ticket key + status, file path).
  "checked Slack" is not a citation.
- **`recent_context[]`** — the last **one or two** actual messages/comments from
  the freshest relevant conversation (the Slack thread, the email, the task
  comments — wherever the ball currently sits). Each: `source`, `who`, `when`,
  and an `excerpt` trimmed to ~200 chars. This is what Dustin reads at a glance
  to sanity-check the ball-owner call without opening the thread himself — so
  quote the real words, don't summarize them. Empty only if there genuinely is
  no conversation to quote.
- **`unverified[]`** — everything the subagent could not confirm, especially
  GAP sources (Freshservice) and anything asserted only by the task itself.

## Digest — how a batch is surfaced

Collate the batch into these groups, in this order, because it maps to what
Dustin *does* with each:

1. **Nudge ready** — `draft_ready: true`, needs his send (`email`, `send`,
   `teams`, or a `note` he approves). Show the `draft` inline here: this group
   should collapse to preview then send.
2. **Waiting on others** — `ball_owner: them`; suggest snooze/reschedule.
3. **Needs a decision from Dustin** — `blocked` or stalled with no clear move.
4. **Closeable / likely done** — `likely-done`; propose `complete`.
5. **Data correction** — `wrong-or-stale-reference`, dupes, mislabels.

**Sort within and across groups by ball-owner + staleness**: `them` with the
largest `days_silent` first — "who owes the next move, and for how long" is the
single most useful signal, so lead with it. Flag related/duplicate tasks
inline so Dustin can merge or close one.

Inline is the default surface. Build the HTML artifact
(`scripts/build_digest.py`) only on request / `--artifact`; it renders the same
groups, phone-skimmable.

## Actions and gating (Phase 2)

Show the current-state picture, the `recent_context[]` quotes, and the
recommended verb with its parameters filled in. Then act only on Dustin's
decision. **The exact invocation for every verb lives in
`references/macros.md`** — this table is the gating contract only.

| Tier | Verbs | Gate |
|---|---|---|
| **Internal, batched** | `note`, `defer`, `move`, `reprioritize`, `link-log` | Show the batch, take **one** approval, then run them all. Reversible and touches nobody else. Each task is still carded first, so a `move` or a bump to `p1` is shown before the approval. |
| **Completion** | `complete`, `drop`, `close-into` | **Its own confirm, per task.** Never folded into the internal batch. |
| **Merge** | `merge` | **One** confirm. Confirming "these are duplicates" *is* confirming the closes it performs. |
| **Outward** | `send`, `teams`, `email` | Full gate, one at a time: draft → humanize → preview → **explicit "send" that turn** → post → log. |
| **Other** | `correct-reference` | Confirm. Posts a note with the correction and never silently rewrites the title. |

**The invariant Dustin chose: recommend, never auto-act.** Batching applies only
to the reversible internal trio, and only as one approval of a *shown* batch. It
is not permission to act silently, and completion is deliberately outside it.
Anything outward-facing is drafted, not sent, until he says so in that turn.

Every writing verb logs itself through `scripts/td_worklog.sh` — the work log is
automatic, not something Dustin should ever have to ask for. Report faithfully: a
drafted-not-sent nudge is recorded as "Drafted", a sent one as "Sent" with its
permalink.
