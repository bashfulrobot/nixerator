# Generators: Gemini and OpenAI

The user generates primarily in **Gemini**, sometimes falls back to **OpenAI**.
Their real behaviour differs in ways that change the prompt, especially around
transparency. Bake the right branch into the emitted prompt.

## Gemini (primary, "nano banana" / Imagen-class)

- **No real alpha.** Even when asked for "a transparent PNG with an alpha
  channel" it returns a **JPEG** and paints a fake transparency **checkerboard**
  into the pixels. There is no honest transparent output. Do not promise it.
- **For a sticker, render on solid magenta and key it out** (Mode C). Replace the
  BACKGROUND line with the magenta block below.
- **Seed lock** is the cohesion lever: reuse one seed across a set for free extra
  consistency on top of the locked STYLE block. Tell the user to set it once and
  keep it.
- **JPEG edges** are slightly softer than PNG, so the magenta key may need a touch
  more `similarity` and can leave faint fringe. `key-magenta.sh` defaults handle
  the common case; bump similarity if fringe survives.
- **Aspect ratio:** state it in words at the end of the prompt, e.g.
  "Aspect ratio 16:9." Use 16:9 for group / hero shots, 1:1 or 4:5 for a single
  subject.

### The magenta BACKGROUND block (use for every Gemini sticker)

```
BACKGROUND: completely fill the entire background, edge to edge, with one solid
flat uniform magenta colour #FF00FF (pure RGB 255,0,255). Evenly lit, no gradient,
no texture, no shadow, no scenery, no checkerboard, no transparency pattern --
just pure flat magenta behind the subject.
```

The "no checkerboard, no transparency pattern" clause matters: without it Gemini
sometimes paints the fake-transparency checkerboard *on top of* the magenta.

Pick the key colour against the subject. Magenta `#FF00FF` is the default because
it is far from most palettes. If the subject is itself magenta or hot pink, choose
another key colour the subject never uses (and update `key-magenta.sh`'s colour).

## OpenAI (fallback, gpt-image-1 / GPT Image)

- **First-class transparency.** Supports `background: transparent` with PNG or
  WebP output, so it can emit a real alpha channel directly. No magenta key
  needed when the transparent flag is set. (If "transparent" is asked for in the
  prose prompt without the API parameter, it can still fake it with a
  checkerboard, so prefer the actual parameter.)
- **Reference image** is the cohesion lever: it accepts an input image, so
  generate the first / cover image, get the user's sign-off, then feed it back as
  the style anchor for every other image in the set. This is usually stronger
  cohesion than a seed.
- **PNG output** means cleaner edges than Gemini's JPEG, so if a magenta key is
  used anyway (some workflows prefer it), `colorkey` comes out cleaner.
- Prefer OpenAI when true alpha or tight cohesion across a large set matters and
  it is available.

## Quotas and keys (from prior runs, verify before relying)

- Some hosted bridges meter a small free tier then require a bring-your-own API
  key.
- A consumer "Gemini Pro" subscription is **not** an API key. A developer key
  comes from `https://aistudio.google.com/apikey` (Gemini) or platform billing
  credits (OpenAI).

## Quick decision

| Need | Use |
|------|-----|
| True transparent PNG, one step | OpenAI with `background: transparent` |
| Tight cohesion across a large set | OpenAI reference image, or Gemini fixed seed |
| Default / what the user reaches for | Gemini + magenta block + `key-magenta.sh` |
| Cleanest cut-out edges | OpenAI (PNG) over Gemini (JPEG) |
