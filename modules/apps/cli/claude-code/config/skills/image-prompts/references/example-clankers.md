# Worked example: atomic-age robot sticker set

A complete example of the LOCKED + VARYING structure, from a real deck. Copy the
**shape**, not the content. The robot style here is one choice; the default of
this skill is style-agnostic sticker transparency, and the locked anchor is built
fresh from each brief.

## The locked block (identical in every prompt of the set)

```
STYLE: Flat 2D hand-drawn cartoon illustration -- thick bold uniform black
outlines, cel-shaded with flat colour fills and simple two-tone shading, subtle
film grain, clean vector-like shapes, no photorealism, no 3D render. The robot is
a retro-futuristic atomic-age "clanker": chunky rounded riveted-sheet-metal body,
a domed or boxy head with a horizontal visor slot showing one or two round glowing
lime-yellow (#CCFF00) eyes, telescoping accordion-tube arms and legs, simple
pincer/claw hands, little antennae, a 1960s Googie / atomic-age industrial look.
PALETTE: brushed-metal grey and off-white body, lime-yellow (#CCFF00) eye-glow and
accent trim, bold black linework -- no other strong colours.
BACKGROUND: fully transparent PNG with an alpha channel, isolated as a clean
die-cut sticker -- no scenery, no ground, no shadow, no background colour.
```

For Gemini, the BACKGROUND line is swapped for the magenta block (see
`generators.md`), then keyed out (see `transparency-pipeline.md`).

## A few varying SUBJECT sentences (one per slide)

Each is one concrete, visual sentence appended after the locked block. Note how
they differ by **character, action, prop, and camera**, never by changing the
style:

- **Cover (group, 16:9):** a cast line-up of FIVE clearly distinct clankers
  standing together like a TV ensemble -- a tall boxy beer-can one, a round
  barrel-bellied one, a one-eyed dome bot on tank treads, a spindly tall-antenna
  one, a stout crab-legged one; confident and friendly, full body, grouped with a
  little margin.
- **"What is a skill":** a clanker with a flip-up visor cap and an open hinged
  chest hatch, sliding a glowing lime "skill card" cartridge into the slot in its
  chest with one pincer, its single lime eye glancing down to watch it seat; full
  body, centred with even margin.
- **Security:** a stout broad-shouldered guard clanker with a riveted barrel
  chest, a badge plate and one big lime scanner-eye, holding up a handheld lime
  scanner wand projecting a small floating lime checkmark hologram -- friendly
  quality-control, not menacing; full body, centred.
- **Good prompts (close-up):** a tidy clerk clanker with a green visor eyeshade,
  shown waist-up close, holding a crisp glowing lime instruction card in one
  pincer and ticking items off it with a tiny lime stylus in the other; centred.

## What the example demonstrates

- The locked block carries the whole set's cohesion; it never changes.
- Distinctiveness comes entirely from the SUBJECT line: a different character, a
  different action, and a different camera distance per slide.
- Slides that risked looking like siblings were separated by changing the action
  and the camera (one installs a card, one is a waist-up close-up), not by
  touching the style.
- The accent hex (`#CCFF00`) is named and confined with "no other strong colours"
  so the set matched the deck and never drifted off-palette.
- IP safety: the source cartoon is never named; only the visual grammar is
  described.
