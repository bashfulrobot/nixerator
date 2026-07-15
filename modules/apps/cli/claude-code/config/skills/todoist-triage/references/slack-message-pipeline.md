# Work-log discipline & the Slack send pipeline

Two related rules for Phase 2: keep the task's work log current, and put any
outward Slack message through a fixed, hard-gated pipeline.

## Work-log discipline

**The task's comments ARE Dustin's work log.** After every triage action —
a nudge sent or drafted, a reschedule, a status/priority change, a decision, a
correction — record it as a comment so the next person to open the task (usually
Dustin, weeks later) sees the current state without re-deriving it. This is the
whole point of the skill: don't let the trail go stale.

- **Always link anything linkable, in Markdown `[label](url)` format.** Todoist
  renders Markdown links. The Slack message just posted, the email thread, a
  Google Doc, a Jira ticket, a call transcript — if there's a URL, link it with
  a human label: `[nudge](https://…)`, `[Apr 9 call summary](https://…)`. A bare
  URL or "see Slack" is not good enough; the point is one-click return to the
  source.
- **Report faithfully.** A message that was drafted-not-sent is logged as
  "drafted"; one that was sent is "sent" with its permalink. Never launder a
  draft into a "sent."
- **Idempotent.** Before adding a work-log comment, scan recent comments; update
  or append rather than duplicating a note that's already there.
- Keep entries terse and factual (who, what, when, link). The breadcrumb, not an
  essay.

## The Slack send pipeline (hard-gated)

An outward Slack message follows this exact sequence. The gates are not
optional — this is Dustin's rule, and skipping a step is a violation of it.

1. **Draft** the message from the assessment.
2. **Humanize** — run it through `humanizer` (customer-facing → `writing-style`,
   which folds in humanizer). Removes AI tells.
3. **Text-polish pass** — apply the rules below to the humanized draft: ruthless
   concision + anti-slop. Produce **only** the final message text. No reasoning,
   preamble, sign-off, or commentary may end up in the message body — the whole
   point of Dustin's text-polish tool is that AI process never leaks into what
   gets sent. Treat the message as a verbatim artifact.
4. **Preview** — show Dustin the final message and stop. **Nothing is sent at
   this step.** This preview is mandatory; he must see the exact text first.
5. **Explicit send** — do nothing until Dustin explicitly says to send it (e.g.
   "send it", "post it"). Silence, a thumbs-up on the assessment, or "looks
   good" on the draft is **not** a send instruction. If in doubt, it's a no.
6. **Post via `/slack-post`** — the send path is the `slack-post` skill, always.
   **Never** post via the Slack MCP (it stamps a "Sent using @Claude" footer;
   slack-post posts cleanly as Dustin). Channel/user lookups may use the Slack
   MCP; only the send bypasses it.
7. **Capture the permalink and log it** — after posting, retrieve the posted
   message's link and add it to the task's work log as a `[label](url)` comment
   (see work-log discipline above). This is why the send goes through the skill
   rather than a manual paste: the loop only closes when the link lands back on
   the task.

If Dustin would rather send by hand, the fallback is the earlier behaviour:
finish at step 4, copy the polished text to his clipboard, and he pastes it —
then he gives you the message link and you log it (step 7).

## Text-polish rules (apply at step 3)

Canonical source: `modules/apps/cli/text-polish/scripts/text-polish.sh` in
nixerator (the `SUPER+SHIFT+R` filter). Re-sync from there if it changes. Applied
here as editing guidance, not by invoking the script.

Say the same thing in as few words as possible. Output only the rewritten text.

Preserve:
- original tone (casual stays casual, formal stays formal, technical stays technical)
- original meaning, in fewer words
- original language (do not translate)
- URLs, links, code blocks, inline code — pass through exactly as-is
- names, product names, technical terms, quoted text — verbatim
- existing Markdown formatting (headings, bold, links); don't add/remove unless restructuring into bullets

Concision:
- cut filler and hedging (really, very, just, quite, basically, actually, I think, I believe — keep hedging only for genuine uncertainty)
- replace adverbs with stronger verbs; wordy phrases with single words ("due to the fact that" → "because", "to be able to" → "can")
- cut redundancy and repeated points; reduce prepositional phrases; convert negatives to affirmatives ("did not remember" → "forgot")
- active voice; short common words ("utilize" → "use")
- start with the point; delete throat-clearing
- average 14–18 words/sentence, no sentence over two clauses
- multiple questions/action items → bullet points; parallel structure in lists

Anti-slop (prose paragraphs only, not bullets):
- never use: additionally, crucial, delve, enhance, foster, landscape, pivotal, showcase, testament, underscore, vibrant, tapestry, intricate, garner, enduring, groundbreaking, nestled, renowned, seamless
- simple verbs: "is" not "serves as", "has" not "boasts"
- **never use em dashes (—) or en dashes (–)** — replace with a comma, or a period between two complete sentences. Absolute.
- prefer commas; replace most colons with a comma or a new sentence (keep a colon only to introduce a bullet list); semicolons only where grammar demands, sparingly
- no rule-of-three, no negative parallelisms ("not just X, but Y"), no significance inflation, no promotional or sycophantic language
