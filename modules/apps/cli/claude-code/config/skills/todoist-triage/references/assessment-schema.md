# Assessment schema, digest, and actions

The fixed contract for a Phase-1 result, plus how a batch of results is grouped
into a digest and what Phase-2 actions are allowed. Keeping the schema fixed is
what lets results from independent subagents collate into one digest.

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
  "what_it_is": "One or two sentences: what this task actually is, in plain terms.",
  "status": "waiting-on-them",
  "ball_owner": "them",
  "days_silent": 12,
  "next_action": "Nudge Priya on the mTLS cert bundle she owed on 2026-06-28.",
  "action_type": "draft-email",
  "draft_ready": true,
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
- **`action_type`** — one of: `post-comment` · `draft-email` · `prepare-slack` ·
  `reschedule` · `complete` · `downgrade` · `correct-reference` · `none`.
- **`draft_ready`** — `true` only if the subagent has enough to prepare the draft
  in Phase 2 without more research.
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

1. **Nudge ready** — `draft_ready: true`, needs his send (`draft-email`,
   `prepare-slack`, or a `post-comment` he approves).
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

One task at a time. Show the current-state picture + recommended `next_action`,
then act only on Dustin's decision in that turn.

| Action | Gating |
|---|---|
| **Post summary / work-log comment** on the task | Humanize first. Record every action here (the comments are Dustin's work log), and link any URL in Markdown `[label](url)` form. **Check existing comments for a recent note — update or skip, never duplicate.** Internal, so no send-gate, but still confirm. See `references/slack-message-pipeline.md` (work-log discipline). |
| **Draft email reply** | Gmail draft via `gws`, correctly threaded (In-Reply-To / References / threadId, clean To). **Never auto-send** — leave the draft for Dustin unless he says "send" this turn. Humanize (customer-facing → `writing-style`). Log it on the task with a `[label](url)` link. |
| **Prepare/send Slack message** | Follow the hard-gated pipeline in `references/slack-message-pipeline.md`: draft → humanizer → text-polish rules → **mandatory preview** → **explicit send** → `/slack-post` (**never** the Slack MCP) → capture permalink → log on the task. |
| **Reschedule** | `td task reschedule <ref> <date>` — preserves recurrence and time-of-day. Preview with `--dry-run` first. Confirm. |
| **Complete** | `td task complete <ref>` (`--forever` to stop recurrence). Only ever *recommended*; Dustin confirms every completion. |
| **Downgrade / relabel** | `td task update <ref> --priority pN` / `--labels ...`. Confirm. |
| **Correct reference** | Post a comment noting the wrong/closed ref and the right one (humanized). Don't rewrite the task title silently. |

**The invariant Dustin chose: recommend, never auto-act.** No completion,
reschedule, downgrade, or send happens without his explicit yes in the moment —
including the "obvious" ones. Anything outward-facing is drafted, not sent. And
report faithfully: a drafted-not-sent nudge is recorded as "drafted."
