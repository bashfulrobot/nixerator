# Slides API deep dive

Load this when building a Slides deck from scratch (no brand template) or when populating speaker notes. The main `gsuite-edit` SKILL.md covers the 90% case of `files.copy` + `replaceAllText`; this file covers the rest.

All commands assume `gws auth status` is green. The JSON bodies are passed verbatim to the underlying Slides API (the same shape you would send via `curl`), so any field documented in the Google Slides REST reference works inside `--json '{...}'`.

## Pattern: create an empty deck

```bash
RESP=$(gws slides presentations create --json '{"title":"My Deck"}')
PRES_ID=$(echo "$RESP" | jq -r .presentationId)
DEFAULT_SLIDE_ID=$(echo "$RESP" | jq -r '.slides[0].objectId')
```

`presentations.create` returns the full presentation object. Its `slides[0]` is a default cover slide with the `TITLE` layout. If you want exactly the slides you add programmatically and not Google's default cover, capture `DEFAULT_SLIDE_ID` and pass a `deleteObject` request in the same `batchUpdate` that creates the real content.

## Pattern: add a slide with deterministic placeholder IDs

`placeholderIdMappings` lets the caller assign object IDs to the layout's TITLE and BODY placeholders inside the same `batchUpdate`, avoiding a fetch-then-update round trip.

```bash
cat > /tmp/slide-1.json <<JSON
{
  "requests": [
    {"deleteObject": {"objectId": "${DEFAULT_SLIDE_ID}"}},
    {
      "createSlide": {
        "objectId": "slide_1",
        "slideLayoutReference": {"predefinedLayout": "TITLE_AND_BODY"},
        "placeholderIdMappings": [
          {"layoutPlaceholder": {"type": "TITLE", "index": 0}, "objectId": "slide_1_title"},
          {"layoutPlaceholder": {"type": "BODY",  "index": 0}, "objectId": "slide_1_body"}
        ]
      }
    },
    {"insertText": {"objectId": "slide_1_title", "text": "Strategic objectives"}},
    {"insertText": {"objectId": "slide_1_body",  "text": "Reduce gateway p99 latency by 25%\nShip Konnect data plane in EU\nAdopt OpenTelemetry across all services"}},
    {
      "createParagraphBullets": {
        "objectId": "slide_1_body",
        "textRange": {"type": "ALL"},
        "bulletPreset": "BULLET_DISC_CIRCLE_SQUARE"
      }
    }
  ]
}
JSON

gws slides presentations batchUpdate \
  --params "{\"presentationId\":\"${PRES_ID}\"}" \
  --json @/tmp/slide-1.json
```

`batchUpdate` applies requests atomically and in order: the `deleteObject` runs before the `createSlide`, so the final deck holds exactly the one content slide. Drop the `deleteObject` request to keep Google's default cover as slide 0.

`createParagraphBullets` with `BULLET_DISC_CIRCLE_SQUARE` converts each newline-separated line in the body shape into a real bulleted list with nested-level styling. Without this request the body text shows up as plain lines, not bullets.

### Layout cheat sheet (`predefinedLayout`)

- `TITLE`: cover slide (title plus subtitle placeholder).
- `TITLE_AND_BODY`: standard content slide (title plus body).
- `SECTION_HEADER`: full-bleed section divider (large centred title).
- `BLANK`: empty slide for hand-positioned shapes.

`index` inside `layoutPlaceholder` is zero-based. `TITLE_AND_BODY` has one TITLE placeholder (index 0) and one BODY placeholder (index 0). Full enum: see the Slides API reference for `PredefinedLayout`.

## Pattern: speaker notes (second round-trip)

The notes page for a slide is created after the slide itself, and its object ID is not addressable via `placeholderIdMappings`. Populate speaker notes in two steps:

1. `presentations.get` to fetch the current presentation tree.
2. Walk to `slideProperties.notesPage.notesProperties.speakerNotesObjectId` for each slide and send a second `batchUpdate` with `insertText` requests.

```bash
NOTES_OBJ=$(gws slides presentations get --params "{\"presentationId\":\"${PRES_ID}\"}" \
  | jq -r --arg sid slide_1 '
      .slides[] | select(.objectId == $sid)
        | .slideProperties.notesPage.notesProperties.speakerNotesObjectId
    ')

[[ -n "$NOTES_OBJ" && "$NOTES_OBJ" != "null" ]] || {
  echo "could not locate speakerNotesObjectId for slide_1" >&2; exit 1
}

gws slides presentations batchUpdate \
  --params "{\"presentationId\":\"${PRES_ID}\"}" \
  --json "{\"requests\":[{\"insertText\":{\"objectId\":\"${NOTES_OBJ}\",\"text\":\"Open with the latency win, then pivot to Konnect EU.\"}}]}"
```

The guard on `$NOTES_OBJ` is load-bearing. Without it, an empty value would post `{"objectId":""}` and Slides returns a confusing API error rather than a clear "slide not found" diagnostic.

For decks with many slides, do one `presentations.get`, then build one `batchUpdate` with one `insertText` per slide. Apply the same guard per slide ID so one missing slide fails the whole batch loudly rather than silently dropping a notes update.

## Trap: `drive.file` scope cannot see Slides decks created via Slides API

A presentation created via `slides.presentations.create` is **not visible to the `drive.file` scope**. Calling `gws drive files get --params "{\"fileId\":\"${PRES_ID}\"}"` from a `drive.file`-scoped token returns 404 immediately after `presentations.create` succeeds, because `drive.file` only sees files the app created via Drive itself. The Slides API created the presentation directly, not through Drive.

Consequences:

1. Hand the user the deterministic URL instead of calling Drive:

   ```
   https://docs.google.com/presentation/d/${PRES_ID}/edit
   ```

2. Widen to the full `https://www.googleapis.com/auth/drive` scope only when the workflow actually needs Drive metadata (parent folder, `modifiedTime`, sharing settings, or `files.update` to move or rename the deck). If the deck stays in the user's My Drive root and just needs to be opened, the default scope set is enough.

## When the from-scratch path is the wrong choice

For customer-facing decks the brand-template path is almost always right; jump back to the main SKILL.md "Pattern: copy a template and fill it in". The from-scratch path documented here produces a deck using Google's default theme, which is rarely what you want for branded work.

If no brand template ID is configured for a Slides build, **ask the user for one** before emitting an unstyled deck. Silently producing a deck in Google's default theme is almost always wrong for the intent. Acceptable user answers: "use this template ID", "save this ID as `<key>` in the cache and use it", or "no theme, default is fine for this one".
