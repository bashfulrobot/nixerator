# Re-theme or recreate a screenshot

The user has an image (often a screenshot) and wants it to match the deck. The
governing rule:

> **Never run a data-bearing screenshot through a generative image model.** It
> silently rewrites numbers, labels, and text. Preserve exact content by
> recolouring deterministically or rebuilding and verifying.

## Getting the image

- **User provides it:** use the file path they give.
- **User directs a capture:** grab it with local tooling, detecting what is
  installed. Never capture unprompted.

```bash
# Wayland
command -v grim   && grim /tmp/shot.png                 # full output
command -v slurp  && grim -g "$(slurp)" /tmp/shot.png    # region select
# X11
command -v maim   && maim -s /tmp/shot.png               # region select
command -v scrot  && scrot -s /tmp/shot.png
command -v import && import /tmp/shot.png                 # ImageMagick, click-drag
# GUI tools
command -v flameshot && flameshot gui -p /tmp
command -v spectacle && spectacle -r -b -o /tmp/shot.png
```

## Classify first, then route

Inspect the image with `Read`. Ask the user if the content's nature is unclear.

1. **Carries data or text that must stay exact?** Tables, charts with axis
   numbers, code, metrics dashboards, anything the audience reads for meaning.
2. **Only colours need to change** -> deterministic **recolour** (below).
3. **Layout / structure should also change** -> faithful **rebuild** (below).
4. **Decorative, no critical data** (hero graphic, icon, mascot, stylised UI with
   no real numbers) -> **generative recreation** is fine: describe the screenshot,
   build a Mode-A prompt with the deck theme locked in, generate fresh.

When unsure whether something is "data", treat it as data. A wrong number on a
slide is worse than a slightly off colour.

## Recolour (deterministic, content-preserving)

For "minimal colour changes to match the theme". Every pixel of content stays put;
only hues move.

### Targeted single-colour swap

`scripts/recolor.sh` replaces one flat source colour with a deck colour:

```bash
scripts/recolor.sh in.png out.png 2962FF CCFF00          # swap blue -> lime
scripts/recolor.sh in.png out.png 2962FF CCFF00 0.18 0.05 # tolerance, blend
```

Chain it per colour for a small palette. It flattens shading within the swapped
region (flat fill in, flat fill out), which is right for solid UI colours and
brand fills. For graded colours use a curves / LUT pass instead.

### Global grade (preserve shading)

When the source has gradients or photos and you want a tonal shift rather than a
flat swap:

```bash
# Hue rotate (degrees) -- shifts all colours together
ffmpeg -y -i in.png -vf "hue=h=40" out.png

# Per-channel curves -- pull the image toward the deck's accent/bg
ffmpeg -y -i in.png -vf "curves=r='0/0 0.5/0.45 1/1':g='0/0.05 1/1':b='0/0 1/0.6'" out.png

# 3D LUT, if you have one for the deck
ffmpeg -y -i in.png -vf "lut3d=deck.cube" out.png
```

### Verify the recolour

Open the result next to the original at full size. Confirm:

- No text edge or thin line was eaten by a colorkey tolerance set too high.
- Every number, label, and glyph is still legible and unchanged.
- The new colours actually match the deck hexes (sample with a colour picker or
  `ffmpeg ... crop=1:1:X:Y` + `od`).

## Rebuild (faithful, fully themed)

When the structure should change too (re-laid-out table, re-plotted chart), do not
recolour pixels. Reconstruct the artifact in a deterministic medium:

- **Table** -> real HTML/CSS table themed with the deck palette and fonts, then
  screenshot it (headless browser) or render to image.
- **Chart** -> re-plot with a charting library (matplotlib, vega, a JS lib) using
  the deck colours.

The accuracy step is mandatory:

1. **Transcribe** every value from the screenshot into the rebuild source.
2. **Read the transcribed values back against the original screenshot** cell by
   cell, point by point, and confirm each one matches.
3. Only then render and deliver.

A rebuild is more work than a recolour, but it is the only accurate way to restyle
data when the layout also changes. If only colour changes, prefer recolour: fewer
chances to introduce a transcription error.

## Deck palette and fonts

Pull these from the live deck source (see the deck-matching section in `SKILL.md`).
Known examples in this user's world (confirm against the source):

- **reveal deck:** bg `#000000`, accent `#CCFF00`, text `#AAB4BB`; Funnel Display
  / Funnel Sans.
- **kong-doc deck:** bg `#001408`, accent `#CCFF00`, grey `#434343`, white text.
