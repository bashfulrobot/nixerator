---
name: image-prompts
version: 1.0.0
description: |
  Turn a short description ("what I want") into a detailed, paste-ready
  image-generation prompt that one-shots consistent results. Use when the user
  asks to generate an image, a set of slide images, artwork, an icon, a sticker,
  a logo-ish illustration, or "a prompt for Gemini / nano banana / OpenAI / an
  image generator", or asks to re-theme / recreate an existing screenshot to
  match a slide deck. Defaults to the sticker style: a clean die-cut subject on a
  transparent background that drops onto any slide regardless of colour. Locks a
  style anchor so a set of images reads as one family, writes prompts to a file
  when they match slide content, and offers to bind the palette to the deck's
  theme. Knows Gemini's and OpenAI's real transparency behaviour and bundles the
  magenta-key pipeline for true alpha.
allowed-tools:
  - Read
  - Write
  - Edit
  - Bash
  - Glob
  - Grep
  - AskUserQuestion
---

# Image Prompts

Take the user's plain-language "what I want" and parameters, and turn it into a
detailed, technical, paste-ready prompt the user copies into an image generator.
The whole point is **one-shot consistency**: the user pastes the prompt once and
gets a usable image, and a *set* of prompts comes out looking like one family.

This skill produces **prompts and re-themes images**. It does not call a hosted
image model itself. The user generates in Gemini (primary) or OpenAI (fallback);
this skill builds the prompt, and for transparency / re-theming it runs local
`ffmpeg` work on images the user brings back.

## Three modes

| Mode | Trigger | Output |
|------|---------|--------|
| **A. Prompt from a description** | "make me an image of...", "prompts for the deck", "a sticker of..." | One or more paste-ready prompts (to a file when they match slides) |
| **B. Re-theme / recreate a screenshot** | "recolour this to match the deck", "recreate this screenshot in the theme" | A re-themed image, by recolour or faithful rebuild, never by guessing data |
| **C. Make a render transparent** | "key this out", "make it a transparent sticker", after a Gemini generation | A verified RGBA PNG via `scripts/key-magenta.sh` |

Pick the mode from what the user asks. They compose: prompt (A) then transparency
(C) is the common path for new sticker art.

---

## The consistency model (read this first, it drives everything)

A one-shot generator cannot be iterated toward a look. Consistency has to be
**written into the text of every prompt**. The mechanism:

- **LOCKED block** -- the STYLE + PALETTE + BACKGROUND anchor. Byte-for-byte
  identical at the top of every prompt in a set. This repeated block is what
  makes separate generations read as the same family. Paste it verbatim.
- **VARYING block** -- one concrete SUBJECT sentence per image. What the subject
  *is* and *does*: pose, prop, gesture, framing. Describe what is **seen**, not
  the abstract idea. "Sliding a card into its chest hatch" generates; "represents
  installing a skill" does not.

When two images in a set collide (look like siblings), fix it by changing the
**action and camera distance** in those two SUBJECT sentences only. Never touch
the locked block to differentiate -- that is what holds the set together.

Full reasoning and the worked iteration history: `references/methodology.md`.

---

## Mode A: build prompts from a description

### 1. Gather the brief, and prompt for specifics if it is thin

These slots drive consistency. If the user left any of them vague and it would
change the output, **ask** (use `AskUserQuestion`) rather than guessing:

- **Subject(s)** -- what is in the frame. For a set, the through-line (same cast?
  different characters in one universe? one motif?).
- **Style / medium** -- flat 2D cartoon, 3D render, line art, watercolour, pixel,
  isometric, photoreal, etc. This is the single biggest consistency lever.
- **Mood / character** -- friendly, serious, playful, technical.
- **Palette** -- exact colours if they matter (see deck-matching below).
- **Background regime** -- default **sticker cut-out** (transparent, no scenery).
  Alternatives: painted flat colour, full scene.
- **Aspect ratio** -- default 1:1 or 4:5 for a single subject, 16:9 for a group
  or hero shot.
- **Generator** -- default **Gemini**. Ask only if transparency handling depends
  on it and the user has not said.
- **One image or a set** -- and if a set, is it per-slide.

Do not over-ask. If the user gave enough to lock a coherent look, proceed and
state the assumptions you made inline so they can correct one cheaply.

### 2. Lock the anchor

Build the LOCKED block once for the whole request:

```
STYLE: <rendering style> + <design language of the subject> + <materials / linework>
PALETTE: <exact hexes and where each colour goes> -- "no other strong colours"
BACKGROUND: <sticker cut-out / painted colour / scene>
```

Rules that make it hold:

- **Front-load the locked style.** Generators weight early tokens; the constant
  part goes first.
- **Name exact hexes and confine them.** End the palette with "no other strong
  colours" so the model does not drift off-palette.
- **Default BACKGROUND = sticker:** "isolated as a clean die-cut sticker -- no
  scenery, no ground, no shadow, no background colour." For Gemini this becomes
  the magenta block (see generators).
- Keep the whole prompt **detailed but not bloated: ~110-170 words.** Enough for
  consistency, short enough that the model does not drop details.

### 3. Write one SUBJECT sentence per image

Concrete and visual. For a set, vary character / action / camera per image while
the locked block stays identical. Map each image to its slide's actual content
when doing a deck (read the deck source, see below).

### 4. Generator-aware emit

Branch the BACKGROUND line and the cohesion advice on the target. Full detail in
`references/generators.md`. Short version:

- **Gemini (default, "nano banana"):** no real alpha, returns JPEG and fakes
  transparency with a painted checkerboard. So for a sticker, render on **solid
  magenta `#FF00FF`** and key it out afterward (Mode C). Offer a **fixed seed**
  for extra cohesion across a set.
- **OpenAI gpt-image-1:** has first-class `background: transparent` and PNG/WebP
  output, so it can emit true alpha directly. It also accepts a **reference
  image** -- generate the first image, get sign-off, then feed it as the style
  anchor for the rest. Often stronger cohesion than a seed.

Pick the key colour against the subject: magenta `#FF00FF` is the default because
it is far from most palettes. If the subject is itself magenta/pink, choose a
different key colour the subject never uses and say so.

### 5. Output to files when matching slides

When the prompts match slide content, **write them to files** (do not only print
them):

- `*.txt` -- paste-ready, one prompt per slide under a `===== SLIDE NN -- TITLE =====`
  delimiter, no commentary. A short header carries aspect ratio + transparency
  fallback + "one shot, regenerate rather than reprompt".
- `*.md` -- annotated: same prompts plus the palette table, the locked anchor
  called out once, and a per-slide role label.

Keep the two in lockstep -- every edit goes to both. For a single one-off image
that is not part of a deck, returning the prompt inline is fine unless the user
wants a file.

### 6. Hand-off note

Always tell the user: **one shot per prompt, regenerate rather than reprompt**,
lock a seed or feed an approved reference image, and generate the first/cover
image first to approve as the anchor the rest must rhyme with.

---

## Deck-theme matching

When the request is for slides, or the user asks to match the deck:

1. **Find the deck source.** Look in the working dir and nearby for `deck.json`,
   a reveal.js `presentation.html` / `index.html`, a Slidev `slides.md`, a MARP
   `.md`, or a theme CSS. `Glob` for these; `Grep` the CSS / JSON for hex codes
   and `font-family`.
2. **Extract the real palette and fonts.** Pull exact hexes -- never guess a
   brand colour. Note which colour is background, which is accent, which is text.
3. **Ask whether to bind to the theme**, and how strongly: accent-only (subject
   keeps its own colours, accents shift to the deck accent), full palette lock,
   or "inspired by". Use `AskUserQuestion`.
4. Fold the chosen hexes into the PALETTE line of the locked block.

Known decks in this user's world (still read the live source to confirm):

- **reveal deck** (claude-presentation): background `#000000`, accent `#CCFF00`
  lime, text `#AAB4BB` silver; fonts Funnel Display / Funnel Sans.
- **kong-doc deck** (`kong-doc-build`): background `#001408` near-black forest
  green, accent `#CCFF00` lime, grey `#434343`, white text.

Both happen to share the lime accent; do not assume that holds for a new deck.

---

## Mode B: re-theme or recreate a screenshot

The user has an image (often a screenshot) and wants it to match the deck.

**Getting the image.** Two ways in, the user picks:

- **The user provides it.** They hand over a file path (or a pasted image saved to
  disk). Use that file directly.
- **The user directs a capture.** They ask the skill to grab the screenshot with
  local tooling. Detect what is installed and use it: on Wayland `grim` (plus
  `slurp` for a region), on X11 `maim` / `scrot` / `import`, or `flameshot gui` /
  `spectacle -r` if present. `command -v` to pick; do not assume. Save to a known
  path, then proceed. The skill never captures unprompted -- only on the user's
  direction.

Once the image is in hand, the hard rule:

> **Never run a data-bearing screenshot through a generative image model.** It
> will silently rewrite numbers, labels, and text. Tables, charts, code, dense
> UI, and anything with exact values must be preserved exactly.

Classify the screenshot first, then route:

1. **Does it carry data or text that must stay exact?** (table, chart with axis
   numbers, code, a metrics dashboard, anything the audience will read for
   meaning.) Inspect it with `Read`; if unsure, ask the user.

2. **Data-bearing + only colours need to change** -> **deterministic recolour.**
   Map the source colours onto the deck palette with `ffmpeg` so every pixel of
   content stays put and only the hues move. `scripts/recolor.sh` does a targeted
   single-colour swap (source hex -> deck hex with tolerance); chain it per
   colour, or use a curves/LUT pass for a global grade. This is the "minimal
   colour changes to match the theme" path. Verify the result side by side with
   the original at full size and confirm no text edge was eaten.

3. **Data-bearing + layout / structure should also change** -> **faithful
   rebuild.** Reconstruct the artifact in a deterministic medium: a table becomes
   real HTML/CSS themed with the deck palette and fonts; a chart becomes a
   re-plotted chart (matplotlib / vega / a charting lib) with the deck colours.
   **Transcribe the values from the screenshot, then read them back against the
   source and confirm every number matches before delivering.** Render the themed
   artifact to an image. This is more work but it is the only accurate way to
   restyle data.

4. **Decorative / illustrative, no critical data** (a hero graphic, an icon, a
   mascot, stylised UI with no real numbers) -> **generative recreation is fine.**
   Describe what is in the screenshot, build a Mode-A prompt with the deck theme
   locked in, and generate fresh.

Detail, ffmpeg recipes, and the rebuild checklist: `references/retheme-screenshot.md`.

When in doubt about whether content is "data", treat it as data and recolour or
rebuild. A wrong number on a slide is worse than a slightly off colour.

---

## Mode C: make a render transparent (true alpha)

Gemini (and OpenAI when asked for "transparent" without the API flag) fake
transparency with a painted checkerboard on opaque pixels. To get real alpha,
render on solid magenta and key it out:

```bash
scripts/key-magenta.sh raw/in.png out.png
```

The script runs `ffmpeg colorkey`, forces `format=rgba`, and verifies the result
from the file bytes (PNG colour type must be 6, corner pixel alpha must be 0) --
because the previewer lies about transparency. Full background, the verification
commands, batch fringe-counting, and known caveats: `references/transparency-pipeline.md`.

Delete the magenta intermediates once the keyed PNG verifies.

---

## IP safety

If the user wants the look of a known cartoon / brand / franchise, **never name
the show, studio, era-as-a-brand, or characters.** Describe the visual grammar
directly instead (linework, shading, shapes, materials, era cues). Concrete
descriptors reproduce a style more reliably than a name and avoid refusals.

---

## Finding the helper scripts

Paths like `scripts/key-magenta.sh` are relative to this `SKILL.md`. Resolve them
to where the skill is installed:

- User skill: `~/.claude/skills/image-prompts/scripts/`
- Project skill: `.claude/skills/image-prompts/scripts/`

Run with `bash <resolved-path>/scripts/key-magenta.sh ...`. Both scripts need
`ffmpeg` on PATH (the claude-code module provides it on workstation hosts).

## References

- `references/methodology.md` -- the full consistency method and why each choice.
- `references/generators.md` -- Gemini vs OpenAI: transparency, seeds, references,
  aspect ratios, quotas, the exact magenta BACKGROUND block.
- `references/transparency-pipeline.md` -- magenta-key + verify-from-bytes, batch QA.
- `references/retheme-screenshot.md` -- classify, recolour vs rebuild vs regenerate.
- `references/example-clankers.md` -- a complete worked example set (atomic-age
  robot stickers) to copy the structure from. It is an example, not the default
  style.
