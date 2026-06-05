# Transparency pipeline: magenta key to true alpha

How to turn a render made on solid magenta into a real RGBA PNG sticker, and how
to prove the alpha is real. `scripts/key-magenta.sh` automates steps 1-2; this
doc is the background and the manual verification.

## TL;DR

1. Generate the subject on a solid magenta `#FF00FF` background (not "transparent").
2. Key the magenta out with `ffmpeg colorkey` -> a real RGBA PNG.
3. Verify the alpha is real (colour type 6, corner alpha 0) and no magenta fringe.
4. Delete the magenta intermediates.

## Why magenta instead of asking for transparency

Image models fake transparency: they return opaque RGB (or JPEG) with a
checkerboard painted into the pixels. It looks transparent in a previewer but is
fully opaque. So "transparent background" prompts are a dead end on those tools.
The reliable fix is chroma key: render on a flat key colour the subject never
uses, then key it out locally.

Use magenta `#FF00FF`, never white or green when the subject is light/grey with a
green accent: white would key out the body, green would eat the accent. Magenta is
maximally distant from most palettes, so the key is safe. If the subject itself is
magenta, pick another unused key colour and pass it to the script.

## Step 1-2: key it out

```bash
scripts/key-magenta.sh raw/in.png out.png
# or with an explicit key colour and tolerance:
scripts/key-magenta.sh raw/in.png out.png 0xFF00FF 0.32 0.12
```

What the filter does (`colorkey=0xFF00FF:similarity:blend`):

- `0xFF00FF` -- the key colour (magenta).
- `similarity` (default `0.32`) -- how far from pure magenta still counts as
  background. The model's "magenta" is never exactly 255,0,255 (grain, slight
  gradient), so this must be loose enough to catch the whole field without eating
  the subject. Bump it for JPEG (Gemini) output.
- `blend` (default `0.12`) -- softens the alpha transition at edges so there is no
  hard jagged cutout and no leftover halo.
- `format=rgba` -- forces a real alpha channel on the output.

## Step 3: verify from the bytes, not the previewer

Two traps: the fake-transparency checkerboard looks identical to a real
transparency grid, and many previewers render raw RGB and ignore alpha (so a
correctly keyed PNG still *displays* magenta). Verify with data:

```bash
# PNG IHDR colour type -- byte 25. Want 6 (RGBA). 2 = RGB (opaque, key not applied).
od -A n -t u1 -j 25 -N 1 out.png        # -> 6

# Corner pixel (background) should be fully transparent: 4th (alpha) byte = 0
ffmpeg -hide_banner -i out.png -vf "crop=4:4:0:0,format=rgba" -f rawvideo - \
  2>/dev/null | od -A d -t u1 | head -1   # -> R G B 0 ...

# Centre pixel (subject) should be opaque: alpha = 255
ffmpeg -hide_banner -i out.png -vf "crop=4:4:in_w/2:in_h/2,format=rgba" -f rawvideo - \
  2>/dev/null | od -A d -t u1 | head -1   # -> R G B 255 ...
```

`key-magenta.sh` runs the colour-type and corner-alpha checks and fails loudly if
either is wrong.

To actually see the result, composite over a solid colour (green makes any magenta
halo scream):

```bash
ffmpeg -y -loglevel error -f lavfi -i color=white:s=600x338 -i out.png \
  -filter_complex "[1]scale=600:-1[fg];[0][fg]overlay=(W-w)/2:(H-h)/2:format=auto" \
  -frames:v 1 /tmp/check.png
```

### Count residual fringe across a batch (want 0)

```bash
for n in $(seq -w 1 16); do
  cnt=$(ffmpeg -hide_banner -i slide$n.png \
    -vf "format=rgba,geq=r='if(gt(alpha(X,Y),20)*gt(r(X,Y),180)*lt(g(X,Y),90)*gt(b(X,Y),140),255,0)':g=0:b=0:a=255,format=gray" \
    -f rawvideo - 2>/dev/null | od -A n -t u1 | tr ' ' '\n' | grep -c 255)
  printf "slide%s magenta-fringe px: %s\n" "$n" "$cnt"
done
```

## Step 4: clean up

The magenta originals are throwaway. Keep only the keyed RGBA finals:

```bash
rm -rf raw /tmp/check.png
```

## Known caveats

- **Keyed-out pixels keep their magenta RGB under alpha 0.** Any consumer that
  ignores alpha will show magenta. Every real deck tool (reveal.js, PowerPoint,
  Keynote, browsers) respects PNG alpha, so this is cosmetic. If a target ignores
  alpha, re-key while flattening the hidden RGB to white, or add a despill pass.
- **Verify colour type per file.** The model occasionally honours "transparent" by
  painting a checkerboard into opaque RGB; the `od ... -j 25` check is the only
  reliable catch.
- **OpenAI (PNG) keys cleaner than Gemini (JPEG).** Gemini's JPEG needs a higher
  `similarity` and may leave faint fringe.
- **No ImageMagick assumed.** If `convert` / `magick` is available,
  `convert in.png -fuzz 25% -transparent magenta out.png` is an equivalent
  one-liner.
