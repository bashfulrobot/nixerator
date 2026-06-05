# Methodology: one-shot, consistent image prompts

Why the skill is built the way it is. The job: produce detailed, paste-ready
prompts that come out **visually consistent across a set** on a generator that is
bad at re-prompting, so every prompt must one-shot.

## Research before writing a single prompt

Do not invent the look in a vacuum when there is a real target:

- **Read the deck source** to get the slide list, order, layout, and the content
  of each slide. The prompt for a slide must depict that slide's idea.
- **Find the real palette.** Grep the theme CSS / JSON for exact hexes. Never
  guess a brand colour. Note which hex is background, accent, text.
- **Learn how the image lands.** Full-bleed background vs a cut-out dropped onto
  the slide changes the whole approach (painted background vs transparent sticker).

## The core problem: consistency on a one-shot generator

A re-prompt-friendly tool lets you iterate toward a look. A one-shot tool does
not: each image is generated cold. So consistency must be **engineered into the
text of every prompt**, not discovered through iteration.

The mechanism: split every prompt into a LOCKED block and a VARYING block.

- **LOCKED -- the STYLE / PALETTE / BACKGROUND anchor.** Identical, byte for byte,
  at the top of every prompt. Same rendering style, linework, materials, palette,
  background treatment. This repeated block is what makes separate generations
  read as one set. Pasting it verbatim is the single most important rule.
- **VARYING -- the SUBJECT + COMPOSITION.** Per image: what the subject is and
  does, and how it is framed.

Supporting cohesion levers (tool-dependent, offer them):

- **Seed lock** if the generator exposes one (Gemini) for free extra cohesion.
- **Reference image** if the generator accepts one (OpenAI gpt-image-1): feed the
  approved first image as a style anchor for the rest. Often stronger than a seed.
- **Generate the cover / first image first**, get sign-off, then treat it as the
  reference the rest must rhyme with.

## Prompt anatomy

```
STYLE: <rendering style> + <design language of the subject> + <materials>
PALETTE: <exact hexes and where each colour goes> -- "no other strong colours"
BACKGROUND: <transparent sticker / painted stage colour / keyable colour>
SUBJECT: <this image's subject> + <action> + <prop> + <framing note>
```

Why this shape:

- **Front-load the locked style.** Generators weight early tokens; the constant
  part goes first.
- **Name exact hexes and confine them.** "...accent (#CCFF00) ... no other strong
  colours" stops the model drifting off-palette.
- **One subject sentence, concrete and visual.** Describe what is *seen* (pose,
  prop, gesture), not the abstract concept. Concrete generates; abstract does not.
- **Detailed but not bloated: ~110-170 words.** Enough for consistency, short
  enough that the model does not drop details.

## Mapping a set to subjects

- **One image per slide**, depicting that slide's actual content.
- **Match the image role to the layout.** Bullet slides -> a single subject with
  the rest of the frame free for text. Statement / section slides -> a fuller hero
  composition. A comparison slide -> two subjects.
- **Differentiate by action and camera, not by character alone.** When two images
  feel like siblings, the fix is not to break the locked style. It is to vary
  pose, prop, and camera distance in those two SUBJECT sentences only. Locked
  block = cohesion; subject action + framing = distinctiveness.

## Variety with cohesion (different characters, one universe)

When the brief is "a different subject per slide but they should still feel
connected":

- Keep STYLE + PALETTE locked (same universe).
- Vary the character / subject design per slide, shaped to that slide's theme.
- Add recurring motifs as connective tissue: a shared accent glow, shared
  materials, and cameos (the cover cast reappearing on the closer).

## Background regimes

- **Painted background** (image is full-bleed): render the deck's stage colour as
  real pixels so it drops straight onto the slide.
- **Transparent cut-out / sticker** (just the subject, placed on the slide's own
  background): "fully transparent PNG with alpha, isolated as a clean die-cut
  sticker -- no scenery, no ground, no shadow." Strip environment from the SUBJECT
  line too: reduce each scene to subject + a handheld or floating prop.

True alpha is generator-dependent. See `generators.md` and `transparency-pipeline.md`.

## IP-safe styling

To evoke a known look without copyright risk: never name the show, studio,
era-as-a-brand, or characters. Describe the visual grammar directly (linework,
shading, shapes, materials, era cues). Concrete descriptors reproduce a style
more reliably than a name and avoid refusals.

## Two-file output convention

- **`*.txt`** -- paste-ready. Just the prompts, each under a clear
  `===== SLIDE NN -- TITLE =====` delimiter, no commentary. A short header carries
  tool-agnostic usage notes (aspect ratio, transparency fallback, one shot).
- **`*.md`** -- annotated. Same prompts plus a usage guide, palette table, the
  locked anchor called out once, and per-slide role labels.

Keep them in lockstep: every edit goes to both.

## The meta-lesson

Lock the thing that must stay constant, expose the thing that must vary, and when
two outputs collide, change only the varying part.
