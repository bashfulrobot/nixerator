# `Next_Steps__c` rich-text formatting standard

The Risk Review narrative lives in `Account_Risk__c.Next_Steps__c`, which is a
Salesforce rich-text field. Salesforce accepts a **subset** of HTML. Design
for legibility and scanning on a white detail page, not decoration.

Apply this standard on every run. Build the HTML in a file and load it into
the payload via `jq --rawfile` (the `build-risk-payload.sh` helper does this)
-- never hand-concatenate HTML into a `--values` string.

## Rules

- **No `<h1>`-`<h6>`.** Their rendering is inconsistent in the detail view.
  Use bold plus `font-size` spans instead.
- **Header line:** the risk level, sized up and bold, then an em-dash entity
  and a coloured one-word status:
  ```html
  <p><span style="font-size: 16px;"><strong>Risk Level: Level N (Colour)</strong></span> &mdash; <span style="color: {rgb};"><strong>{status word}</strong></span></p>
  ```
  Immediately follow it with a one-line italic framing:
  ```html
  <p><em>{one-line framing of the risk}</em></p>
  ```
- **Risk-level colour** (the *only* place coloured text is allowed -- the
  status word). Chosen for legibility on white; avoid pure yellow, which is
  unreadable:
  | Level | RGB |
  |---|---|
  | Red | `rgb(200, 30, 30)` |
  | Yellow / amber | `rgb(181, 132, 0)` |
  | Green | `rgb(33, 118, 51)` |
- **Section headers**, sized `15px`, bold:
  ```html
  <p><span style="font-size: 15px;"><strong>1. Impact</strong></span></p>
  <p><span style="font-size: 15px;"><strong>2. Playbook Check &mdash; Actions Taken</strong></span></p>
  <p><span style="font-size: 15px;"><strong>3. Help Needed &mdash; Specific Ask</strong></span></p>
  ```
- **Points:** one `<ul>` per section. Each `<li>` opens with a bold lead-in
  label, e.g. `<strong>Specific Risk:</strong> ...`. Keep bullets tight -- no
  blank line between bullets inside a section.
- **Emphasis:** bold the key figures (money, %, dates, product names, the
  single-thread contact). Italic for the subtitle and short asides. Underline
  (`<u>`) the specific ask, or the words "No specific ask at this time".
- **Spacing:** exactly one `<p><br></p>` between sections; none between
  bullets.
- **Avoid:** `<h1>`-`<h6>`, emojis, coloured text anywhere except the
  risk-level status word, and tables -- unless a tiny renewal-reconciliation
  table genuinely earns its place.

`Help_Needed__c` stays **plain text**: one short awareness paragraph, no HTML.

## Fill-in skeleton

Copy this into `next_steps.html`, replace the `{...}` placeholders, drop any
`<li>` you have no content for, and set the colour to match the level. The
prose inside must already have been through `text-polish`.

```html
<p><span style="font-size: 16px;"><strong>Risk Level: Level {N} ({Colour})</strong></span> &mdash; <span style="color: {rgb};"><strong>{status word}</strong></span></p>
<p><em>{one-line framing of the risk}</em></p>
<p><br></p>
<p><span style="font-size: 15px;"><strong>1. Impact</strong></span></p>
<ul>
<li><strong>Specific Risk:</strong> {what is actually at risk}</li>
<li><strong>Revenue Impact:</strong> {<strong>$ and %</strong>, tied to the contract number}</li>
<li><strong>Strategic Risk:</strong> {broader account / relationship stakes}</li>
<li><strong>Customer Sentiment:</strong> {what the CSM has heard, from whom}</li>
</ul>
<p><br></p>
<p><span style="font-size: 15px;"><strong>2. Playbook Check &mdash; Actions Taken</strong></span></p>
<ul>
<li>{action 1}</li>
<li>{action 2}</li>
</ul>
<p><br></p>
<p><span style="font-size: 15px;"><strong>3. Help Needed &mdash; Specific Ask</strong></span></p>
<p><u>{the specific ask}</u></p>
```

For an awareness-only risk, the section-3 line reads:
`<p><u>No specific ask at this time.</u> Logged for awareness.</p>`

## Worked example (Nordstrom, Level 2 / Yellow)

```html
<p><span style="font-size: 16px;"><strong>Risk Level: Level 2 (Yellow)</strong></span> &mdash; <span style="color: rgb(181, 132, 0);"><strong>Watching closely</strong></span></p>
<p><em>The Mesh renewal is on track on paper, but the canary rollout that justifies the expansion has stalled, and the one person driving it has gone quiet.</em></p>
<p><br></p>
<p><span style="font-size: 15px;"><strong>1. Impact</strong></span></p>
<ul>
<li><strong>Specific Risk:</strong> The phased canary rollout of <strong>Kong Mesh</strong> into the checkout path has been paused for <strong>six weeks</strong>.</li>
<li><strong>Revenue Impact:</strong> <strong>$480,000</strong> renewal ACV at stake, plus a planned <strong>$180,000</strong> expansion tied to the rollout.</li>
<li><strong>Strategic Risk:</strong> Nordstrom is a named Mesh reference in retail; a stalled rollout puts the reference at risk.</li>
<li><strong>Customer Sentiment:</strong> The <strong>platform lead</strong> stays positive, but the checkout team has raised latency concerns.</li>
</ul>
<p><br></p>
<p><span style="font-size: 15px;"><strong>2. Playbook Check &mdash; Actions Taken</strong></span></p>
<ul>
<li>Ran a joint architecture review on the sidecar latency numbers.</li>
<li>Escalated the checkout latency question to Kong support.</li>
<li>Booked a technical working session for the week of the renewal.</li>
</ul>
<p><br></p>
<p><span style="font-size: 15px;"><strong>3. Help Needed &mdash; Specific Ask</strong></span></p>
<p><u>Need a Mesh product SME for one 60-minute session</u> to close out the checkout latency question before the renewal. No exec escalation needed yet.</p>
```

Matching `Help_Needed__c` (plain text):

```
Need a Mesh product SME for one 60-minute session to close out the checkout
latency question before the renewal conversation. No exec escalation needed yet.
```
