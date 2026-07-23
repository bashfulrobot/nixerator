---
name: kong-success-plan-pptx
description: Build a Kong customer success-plan PPTX in Kong CS's official three-slide format (cover, strategic objectives, workstreams and milestones), with an optional fourth deep-dive slide. Use when the user asks to build a customer success plan deck, "Kong success plan PPTX", QBR success-plan slides, or references the official Kong CS success-plan format.
---

## When to use

Trigger when the user asks for any of:

- A customer success-plan PPTX in the Kong CS standard format
- A "Kong success plan deck" / "success plan slides" / "success plan PPT"
- A QBR / EBR success-plan deck for a specific customer
- A renewal-cycle success-plan deck
- A deep-dive companion slide on the customer's initiatives

Do NOT trigger for general Kong slide decks, customer-facing pitches, EBRs that don't follow the success-plan layout, or non-PPTX outputs. Use the `kong-pptx-build` (general Kong-branded decks) or `revealjs` skills for those instead.

## What this skill does

Renders a 3- or 4-slide PPTX from a JSON content file:

1. **Cover** — `<Customer> Kong / Success Plan / <Date>`, CSM line, customer-specific tagline.
2. **Strategic Objectives** — three numbered priority outcomes (heading + 1-2 bullets each), plus a bottom-line takeaway.
3. **Workstreams and Milestones** — four numbered initiatives (title, date, status, 1-3 bullets each), with a key-success-indicators footer and a status-color legend.
4. **Initiative Deep Dive** *(optional)* — same four-up layout, but used to surface the bottleneck and play for each initiative. Only emitted when the JSON contains a `deep_dive` section.

Layout, fonts, footer bar, and Kong brand styling are inherited from the bundled template. The script only replaces text; it never edits the template's geometry or theme. The bundled template was checked against Kong's official 2026 v1.1 brand system (see the `kong-branding` skill) and already uses the correct colors (`#000F06`, `#B7BDB5`) and fonts (Funnel Sans, Space Grotesk, Urbanist) directly — no drift to correct here.

## How to use

1. **Gather the customer's content.** Synthesize from running notes, transcripts, prior success plans, or whatever the user provides.
2. **Write a JSON content file** following the schema below. Use `examples/example-customer.json` as a starting point — copy it, then replace the customer-specific values.
3. **Run the build script:**

   ```bash
   python3 ~/.claude/skills/kong-success-plan-pptx/scripts/build.py \
     --input <customer-content>.json \
     --output <customer>-Kong-Success-Plan.pptx
   ```

   Stdlib-only Python 3.10+, no extra deps. On NixOS use `nix run nixpkgs#python3 --` instead of `python3` if Python is not on `$PATH`.

4. **Visually QA the output** before sending to the customer. Convert to PDF with LibreOffice (`soffice --headless --convert-to pdf <out.pptx>`), then to PNGs with `pdftoppm` to inspect each slide. Real PowerPoint may render minor pixel differences; LibreOffice is good enough for layout-overlap checks.

5. **Add images post-render.** This skill is text-and-layout only. The cover comes with the Kong Konnect mark already in place. If the customer wants their own logo too, drop it in PowerPoint after the deck renders.

## Content schema

JSON file with three required sections (`customer`, `objectives`, `workstreams`) and one optional (`deep_dive`):

```jsonc
{
  "customer": {
    "name": "<Customer name>",          // becomes "<Customer> Kong" on cover
    "csm": "<CSM name> - Technical CSM",
    "date": "Month YYYY",
    "tagline": "<one-line value-prop tagline>"
  },
  "objectives": {
    "title": "Strategic Objectives Driving the Program",   // optional override
    "subtitle": "<Customer>'s priority outcomes",          // optional override
    "takeaway": "<One sentence on why these priorities matter>",
    "items": [
      {
        "heading": "OBJECTIVE ONE",                        // ALL CAPS recommended
        "bullets": ["bullet 1", "bullet 2"]                // 1-2 bullets per item
      },
      {"heading": "OBJECTIVE TWO", "bullets": [...]},
      {"heading": "OBJECTIVE THREE", "bullets": "single descriptive sentence"}
    ]
  },
  "workstreams": {
    "title": "Workstreams and Milestones",                 // optional override
    "subtitle": "Where we are and where we are driving next", // optional override
    "footer": "KEY SUCCESS INDICATORS   |   <metric>   |   <metric>   |   <metric>",
    "items": [
      {
        "title": "<Workstream name>",
        "date": "Q3 2026",                                 // or "Nov 2025", "Apr 2026", etc.
        "status": "In Progress",                           // free text — fits the badge
        "bullets": ["bullet 1", "bullet 2", "bullet 3"]    // 1-3 bullets, keep short
      }
      // up to 4 items; extras are ignored
    ]
  },
  "deep_dive": {                                           // optional fourth slide
    "title": "Initiative Deep Dive",                       // optional override
    "subtitle": "Bottlenecks we know about and the plays we are running", // optional
    "footer": "OWNERS   |   <CSM>   |   <AE>   |   <SE>",
    "items": [
      {
        "title": "<Initiative>",
        "date": "Owner: <Name>",                           // repurpose the date slot
        "status": "Active",
        "bullets": ["Bottleneck: ...", "Play: ...", "Supporting action"]
      }
      // up to 4 items
    ]
  }
}
```

## Authoring rules

- **Bullets must be short.** Aim for 1-2 visual lines per bullet (~50-65 characters). The reference deck wraps cleanly at that length; longer bullets will clip even with the script's bullet-box height extension. If the customer's content is dense, use the `deep_dive` slide for detail rather than overstuffing slide 3.
- **Keep status-pill text short** ("In Progress", "Complete", "Active", "At Risk"). Long status text wraps awkwardly inside the badge.
- **Use ALL CAPS for objective headings** on slide 2. The reference template renders them in bold uppercase regardless, but writing them that way in source makes the JSON readable.
- **Three objectives, no more, no less.** Slot 3 supports a single sentence (string) instead of a bullet list when the objective fits better as one descriptive line. Extra objectives are silently dropped.
- **Four workstreams, no more.** Same rule. If a customer has more, group them.
- **Numbers come from order in the JSON.** Don't try to override the "1" / "2" / "3" / "4" badges via the script.
- **Run any drafted prose through the `text-polish` skill** before encoding into JSON — slide-2 and slide-3 prose is highly visible and AI tells (em dashes, "leverage", inflated significance language) read poorly in front of a customer.

## Status legend

The footer of slide 3 (and slide 4) carries a fixed legend:

> STATUS: 🔵 Complete | 🟢 On Track | 🟠 At Risk | 🔴 Delayed

This is not customer-editable. Status pills inside the workstream cards take free-text strings and don't have to match the legend, but using the same vocabulary keeps the deck coherent.

## Inputs needed from the user

If the user just says "build a success plan PPTX for X," ask for:

1. The customer's three top business outcomes for the period
2. The four workstreams Kong is driving for them, with status and brief outcome description
3. Stakeholder map for the deep-dive slide (CSM, AE, SE, customer owner)
4. KPI baselines for the slide-3 footer (licensed services, request volume, stakeholder engagement, etc.)
5. Date and CSM name for the cover

If a markdown success plan already exists (e.g. from a prior `success-planning-framework` invocation), translate it to JSON directly — that's faster than asking the user to fill out a form.

## Limitations

- **Text and layout only.** Cannot embed images, edit the theme, or add new slide types beyond the four shipped layouts.
- **Bullet count caps at 3 per workstream box.** The bullet box height was extended to fit 3 medium-length bullets cleanly. Four short bullets fit too, but four long bullets will clip.
- **Visual QA in LibreOffice may show minor artifacts** that don't appear in PowerPoint — usually a tiny Z-order quirk on the status badges. PowerPoint is the canonical render target.
- **Customer logo swap is manual.** Do it in PowerPoint after rendering.
