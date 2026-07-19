---
name: text-polish
description: |
  Clean up and tighten text in one pass: humanize, then apply Dustin's concision
  rules, then revalidate that meaning and facts survived. Use whenever Dustin asks
  to "polish" text, wants "polished text", or says tighten / trim / clean this up /
  make it concise. Also the cleanup layer other writing skills call. One invocation
  runs both the de-slop and the concision pass, so Dustin never has to separately
  ask for the humanizer.
---

# Text Polish

Turn a draft into clean, tight, human prose in a single invocation. This skill is
the session-side counterpart to the SUPER+SHIFT+R keybind filter: same concision
rules, but wrapped with a humanizer pass and a final accuracy check, because a
session has a model in the loop and a live paste does not.

## What it owns

Concision plus de-slop. It does **not** own voice. Making text sound like Dustin is
`writing-style`; that skill calls this one for cleanup and then restores voice.

## Process

Run these in order on the given text. One invocation, all steps.

1. **Humanize.** Invoke the `humanizer` skill (via the Skill tool) for generic
   anti-AI-slop cleanup. This is built in, so Dustin never has to ask for it
   separately. Skip only when the caller already ran humanizer this turn (e.g.
   `writing-style` delegating here) to avoid double-processing.
2. **Concision pass.** Apply the rules in `references/concision-rules.md` (the same
   file the keybind filter uses). Say the same thing in fewer words: cut filler and
   throat-clearing, single words over wordy phrases, active voice, plain verbs. No
   em or en dashes. Prefer commas over colons in prose (colon only to introduce a
   bullet list). No rule-of-three, no promotional language. Multiple asks become
   bullet points.
3. **Revalidate context and accuracy.** Concision is aggressive, so verify the
   tightened text before presenting:
   - every question, ask, and action item from the original survived,
   - no qualifier was dropped that changes a fact (dates, scope words like "for
     2025 only", "N-1", numbers, names),
   - no connective was flipped in a way that shifts meaning ("and" to "but"),
   - tone still matches the original register.
   If the pass broke any of these, fix it and note what you restored. This step is
   the whole reason the session version exists instead of just running the keybind.
4. **Present** the polished result.

## Strength: full vs voice-preserving

- **Standalone** (`/text-polish`, "polish this", a commit body, a Jira ticket, a
  doc): run at full strength. There is no personal voice to protect.
- **Called by `writing-style`**: run in preserve-voice mode. The concision rules
  already say "casual stays casual", but Dustin's voice deliberately keeps things a
  generic tightener would cut (warm exclamation, sentence fragments, "Happy to
  help.", smileys). When concision and voice conflict, **voice wins** and
  `writing-style`'s voice pass restores it. The step-3 revalidation is where a
  flattened voice element gets caught and put back.

## Not this

- The SUPER+SHIFT+R app keybind is a separate consumer of the same
  `concision-rules.md` and must stay concision-only (no humanizer, no narration).
  This skill is the session process, not that filter.
- This skill does not add or impose Dustin's voice. That is `writing-style`.
