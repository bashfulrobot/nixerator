---
theme: neversink
title: Personal Deck
info: |
  ## Personal Slidev deck
  Built on the Neversink community theme.
  Docs: https://gureckis.github.io/slidev-theme-neversink/
colorSchema: auto
neversink_slug: 'My Talk'
transition: fade
mdc: true
layout: cover
color: navy-light
---

# A talk for humans

by **Your Name**

:: note ::

* Cover slide. The default slot is the title + author. The optional `:: note ::`
  slot renders smaller text at the bottom (good for venue / event line).

---
layout: intro
color: amber-light
---

# About me

Short bio that goes here. Two or three sentences max -- intro slides hold the
room while you settle in. `:: note ::` works here too.

---
layout: top-title
color: sky
align: lt
---

:: title ::

# What we'll cover

:: content ::

- The thing we're going to talk about
- Why it might matter to you
- What you'll be able to do after

<!--
top-title: title at top, content below. align controls justification of each
region; `lt` = left-aligned title, left-aligned content.
-->

---
layout: two-cols-title
columns: is-6
align: l-lt-lt
color: emerald-light
---

:: title ::

# Before / after

:: left ::

## Before

- Manual process
- Tribal knowledge
- One-off scripts

:: right ::

## After

- Automated pipeline
- Documented runbook
- Reusable tooling

<!--
two-cols-title: title across the top, two columns below. `columns: is-6` =
50/50 split (Bulma-style sizing). `align: l-lt-lt` = title-left, left-col
top-left, right-col top-left.
-->

---
layout: section
color: violet
---

# A section divider

---
layout: top-title
color: rose-light
align: lt
---

:: title ::

# Highlights and asides

:: content ::

You can highlight inline using ==double equals== for emphasis.

<AdmonitionType type="tip" width="380px">
Tip-style admonition. AdmonitionType handles colour and icon automatically.
Available types: info, important, tip, warning, caution.
</AdmonitionType>

<AdmonitionType type="warning" width="380px">
Use admonitions sparingly -- one per slide reads as deliberate, three reads
as panicked.
</AdmonitionType>

---
layout: full
color: navy
---

<StickyNote color="amber-light" textAlign="left" width="240px" title="Aside" v-drag="[120, 140, 240, 'auto']">
Sticky notes float anywhere on the slide. Drop them via the `v-drag` directive
or position them with utility classes.
</StickyNote>

<StickyNote color="lime-light" textAlign="left" width="240px" title="Dev note" devOnly v-drag="[420, 200, 240, 'auto']">
`devOnly` notes show in `slidev dev` but disappear from builds and exports --
perfect for speaker reminders.
</StickyNote>

<!--
The `full` layout strips chrome so components like StickyNote can use the whole
canvas. Drag-positioned components need `v-drag="[x, y, w, h]"` (or 'auto').
-->

---
layout: quote
color: indigo-light
quotesize: text-2xl
authorsize: text-base
author: 'Eleanor Roosevelt'
---

The future belongs to those who believe in the beauty of their dreams.

---
layout: top-title
color: white
align: lt
---

:: title ::

# Stats and numbers

:: content ::

<div class="grid grid-cols-3 gap-8 ns-c-tight">

<div>

## 10x
faster than the old workflow

</div>

<div>

## 0
manual steps remaining

</div>

<div>

## ∞
caffeine consumed getting here

</div>

</div>

<!--
Neversink doesn't ship a dedicated stats layout -- compose one with UnoCSS
grid utilities (built into Slidev) and `ns-c-tight` for compressed bullets.
-->

---
layout: credits
color: light
speed: 0.4
loop: true
---

<div class="grid text-size-4 grid-cols-3 w-3/4 gap-y-10 auto-rows-min ml-auto mr-auto">

<div class="grid-item text-center col-span-3">

# Thank you

Movie-style scrolling credits. `speed:` controls velocity, `loop: true` restarts.

</div>

<div class="grid-item text-right mr-4 col-span-1"><strong>Speaker</strong></div>
<div class="grid-item col-span-2">Your Name<br/>your.email@example.com</div>

<div class="grid-item text-right mr-4 col-span-1"><strong>Slides</strong></div>
<div class="grid-item col-span-2">github.com/you/talk-slug</div>

<div class="grid-item text-right mr-4 col-span-1"><strong>Built with</strong></div>
<div class="grid-item col-span-2">Slidev<br/>slidev-theme-neversink<br/>UnoCSS</div>

<div class="grid-item col-span-3 text-center mt-180px mb-auto font-size-1.5rem">
<strong>Questions?</strong>
</div>

</div>
