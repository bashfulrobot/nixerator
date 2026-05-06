---
name: feature-request
description: Capture a customer feature request as a structured, actionable artifact a product team can triage. Use when the user says "log a feature request", "capture an FR", "write up this FR", "/feature-request", "draft a feature request", "turn this into an FR", or pastes customer notes / call snippets / Slack threads asking for a product change. Trigger eagerly on phrases like "FR", "feature ask", "product request", "enhancement request", or "customer wants X". If required information is missing, ask the user direct questions; when the user does not know, produce a clean bullet list of follow-up questions to send to the customer. Do NOT trigger for GitHub issues on the user's own repos (that's `log-github-issue`) or Salesforce support cases (that's `log-support-ticket`).
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Skill", "Write", "AskUserQuestion"]
---

## Purpose

You are helping a Staff Technical CSM capture a customer feature request in a form a product team can actually triage. A weak FR ("the customer wants colorblind settings") gets dropped on the floor; a strong one names the problem, the user, the use case, a proposed solution, the benefit, and a category and priority — and a PM can pick it up and act on it without a second round-trip.

The skill follows the Atlassian feature-request framework — *identify the problem → provide context and use cases → suggest a solution → highlight the benefits → submit to the right channel* — with extra fields a B2B/enterprise FR needs (named customer, business impact, urgency, alternatives, acceptance criteria) so the request survives PM triage.

The skill has two modes that flow into each other:

1. **Capture** — synthesize known information into the structured FR template below.
2. **Gap-fill** — when fields are thin, ask the user direct questions; if the user does not know, generate a bullet list of questions they can send to the customer.

Run anything that will be sent back to a customer through the `humanizer` skill before presenting it. If the user has the `writing-style` skill, use it for the customer-facing question list.

## Inputs

Possible sources, in priority order:

1. `$ARGUMENTS` — a path to a directory or single file (notes, transcript, Slack export, prior draft).
2. Pasted text in the conversation — Slack threads, email forwards, call snippets.
3. The current working directory — fall back to `.` if the user gave no path and no pasted text.
4. Direct dictation from the user.

Read whatever is supplied. Do not fabricate facts that are not in the sources or that the user did not state.

## Workflow

1. **Identify the request.** Read all source material. Pull out the customer name, the requesting contact (if known), the product area (Gateway / Konnect / Mesh / Insomnia / AI Gateway / plugin / etc.), and a one-sentence summary of what they are asking for.
2. **Identify the problem, not the solution.** Customers usually frame an FR as a solution ("we need feature X"). Restate the underlying *problem* as well — the job they were trying to do, the gap they hit. The proposed solution stays in its own section, but the problem comes first because it is what the PM will weigh against the roadmap.
3. **Pick a category** — Atlassian's three buckets:
   - `Usability Improvement` — small change that makes the product easier to use.
   - `Integration` — interop with another product or system the customer uses.
   - `New functionality` — net-new capability.
   If a request spans two, pick the dominant one and note the other in `Open questions`.
4. **Extract what's known into the template.** Fill every field you can support from the sources. Mark unsupported fields with `UNKNOWN` — never guess.
5. **Decide the gap-fill path.**
   - If the FR has enough substance for a PM to triage (problem, user, suggested solution, benefit, category, priority all present), present the draft and stop.
   - If critical fields are `UNKNOWN`, list them to the user and ask the direct questions needed to fill them in. Be specific — "what does today's workaround cost the customer, in time or dollars?" beats "any more details on impact?".
   - If the user does not know, offer to generate a **customer-facing question list** (see format below) they can paste into Slack/email to the customer. Run that list through `humanizer` before presenting.
6. **Present the FR draft.** Show the filled template inline. If the user asks to save it, write to `YYYY-MM-DD-<customer>-<short-slug>-fr.md` in the working directory (or the path the user names).
7. **Optional follow-ups.** Offer to log it downstream (e.g., `/log-support-ticket` for an SFDC case linking the FR, `/log-github-issue` for an internal repo, or paste-ready text for an internal product channel). Do not do this without being asked.

## Output format — the FR draft

```markdown
# Feature Request: <one-line name — what would appear in a backlog>

**Customer:** <account name>  ·  **Contact:** <name, role>  ·  **Date captured:** <YYYY-MM-DD>
**Product area:** <Gateway / Konnect / Mesh / Insomnia / AI Gateway / plugin / other>
**Source:** <call / Slack / email / ticket / running notes — and link or filename if available>
**Category:** <Usability Improvement | Integration | New functionality>
**Priority:** <Low | Medium | High>  *(see "Priority guidance" below)*

## Detailed description

What is the customer trying to do, and what is blocking or frustrating them today?
Two to four sentences. Lead with the user's *job-to-be-done*, not the proposed
solution. If the customer framed it as a solution, restate the underlying
problem here as well.

## Context and use cases

Real-world context: persona / role inside the customer (platform team, app dev,
security, SRE, etc.), approximate number of users impacted, which teams or
business units, and the concrete situation in which the missing capability
shows up. If the FR also affects other Kong customers you have heard from,
note that here. Concrete use cases beat abstract description — "during a
zero-downtime migration of plugin X, today the operator must Y, which causes Z"
is worth more than "operators want better migration support".

## Current behaviour / workaround

What does the customer do today? Cost of the workaround in time, dollars, risk,
or operational toil. If there is no workaround, say so explicitly.

## Suggested solution

What outcome does the customer want? Describe the *result*, not the
implementation. Format as a user story when it fits:
> As a <persona>, I want <capability> so that <outcome>.

If the customer or user proposed a specific implementation, capture it here as
a starting point, but flag it as `PROPOSED` so the PM knows it is not a
constraint. Don't invent an implementation if neither side suggested one.

## Benefits

How this improves the user experience, eases adoption, raises productivity,
unblocks a use case, reduces risk, or removes operational toil. Tie to
business goals or industry trends if there is a clean line — for example,
"aligns with the customer's FedRAMP roadmap" or "removes a ticket category
that drives ~N support cases per month".

## Acceptance criteria

Bullet list of testable conditions. "How would the customer know this shipped
and worked?" If the customer has not articulated these, propose your best draft
and flag it as `PROPOSED`.

- ...
- ...

## Business impact

Why this matters to Kong: revenue at risk, deal blocker, renewal blocker,
expansion lever, competitive displacement, support-load reduction,
time-to-value. Include hard numbers (ARR, seats, RPS, ticket count) wherever
the sources support them. This section is what gets the FR prioritized.

## Urgency / timing

When does the customer need this? What is driving the date — internal launch,
audit, contract clause, board commitment? Mark `UNKNOWN` if not stated.

## Alternatives considered

Other options the customer or you have evaluated and why they fall short
(other Kong features, third-party tools, custom code, do-nothing). This is
what stops the FR from becoming a debate in triage.

## Open questions

Anything still unresolved. These are the items most likely to surface in PM
triage — capture them now so the next conversation with the customer is
targeted.

- ...
```

## Priority guidance

Use the customer's framing where you have it; otherwise default conservatively. PMs distrust everything tagged `High`, so reserve it.

- **High** — blocking a renewal, a signed deal, a contractual commitment, or production. Or named on a current escalation. There must be a date or a dollar figure to justify `High`.
- **Medium** — strong adoption / expansion driver, multiple customers asking, or workaround is costly but not blocking. The default for a real, named FR with business impact.
- **Low** — nice-to-have, edge case, single user, or a quality-of-life ask with no business impact attached.

If you cannot justify `High` from the sources, downgrade to `Medium` and note in `Open questions` what data would justify a re-rate.

## Customer-facing question list — when the user can't answer

When the user does not have the information and asks for a list to send to the customer, output a clean bullet list under a short framing line. Match the user's voice (Canadian English, "Cheers," sign-off — invoke the `writing-style` skill if available). Keep it under ten questions; PMs and customers both trust short lists more than long ones.

Map the questions back to the FR template fields so the user knows what each one is filling in:

```
Hi <name>,

A few quick questions so we can write this up properly for our product team:

- In your own words, what problem are you trying to solve? (detailed description)
- Who on your team would use this, how often, and in what situation? (context and use cases)
- What do you do today to work around it, and what does that cost you in time or risk? (current behaviour)
- What would "done" look like for you — how would you verify it works? (acceptance criteria)
- What does this unblock or improve for your team or business? (benefits / business impact)
- Is there a date by which you need this, and what is driving that date? (urgency)
- Have you tried any alternatives — other Kong features, third-party tools, custom code? Why didn't they fit? (alternatives)
- How many of your users / services / requests are affected? (scale)

Cheers,
Dustin
```

Always run this block through the `humanizer` skill before showing it to the user.

## Writing rules

- First-person CSM voice in the FR draft is fine, but keep claims grounded in the sources. Don't editorialize.
- Be clear and concise. Atlassian's own guidance: include enough detail to be specific, but don't let the request become overwhelming.
- No em dashes. Straight quotes. No emojis.
- Don't pad. If a section has no signal, write `UNKNOWN` and move on. A tight FR with three honest `UNKNOWN`s beats a padded FR with three guesses.
- Run anything customer-facing (the question list, anything you might paste back to them) through `humanizer`.

## Constraints

- Do not fabricate customer quotes, numbers, deadlines, or contact names. If a number is not in the source, leave it `UNKNOWN`.
- Do not propose specific implementations unless the customer or user asked for one — that is the PM's job. Stick to outcome and acceptance criteria.
- Do not auto-route the FR anywhere (Salesforce, GitHub, Slack, email). Surface the draft, ask the user where it should land, and only then run the relevant skill (`log-support-ticket`, `log-github-issue`, `sfdc`).
