# Template discovery and ID caching

Load this when the user wants to *discover* what Workspace templates exist (rather than already having a template file ID in hand). The main SKILL.md covers the "I have a template ID, copy and fill it" path; this file covers the discovery and caching layer.

## Background: what "New from template" actually is

When a Workspace user opens Docs/Sheets/Slides and clicks **File → New → From a template gallery**, they see two sections:

1. **General templates**: Google-provided defaults (Resume, Project Tracker, Meeting Notes, etc.). Real Drive files owned by Google with stable, publicly-known file IDs.
2. **Your org's templates**: admin-published templates specific to the Workspace tenant. The admin configures these in Admin Console → Apps → Google Workspace → Drive and Docs → Templates. Behind the scenes, this points at a Drive folder. Anything in that folder shows up in the gallery.

**There is no dedicated `templateGallery` REST endpoint.** The Drive UI is rendering a normal Drive folder. Programmatic access is just `files.list` against the right folder, plus `files.copy` to clone an entry.

### Implications

- If the user knows a template file ID (because they opened it once or got a link), copy works immediately, no special handling.
- If the user wants to discover what templates exist, you need the **template gallery folder ID** for their org. Ask the user. If they don't know, they can ask their Workspace admin, or pull it from any template's `parents` field after copying one from the UI once.
- For Google-provided general templates, the easiest path is to copy one through the UI once, then capture the resulting copy's `parents`/`originalFilename`/template metadata to identify the source.

## Finding the org template gallery folder ID

Three ways:

1. **Ask the Workspace admin.** Fastest. The admin configured it.
2. **Inspect a template URL.** Open the Workspace template gallery in the browser, click any template, copy the URL. The path includes the document's file ID. Look up that file's `parents` field to get the gallery folder ID.
3. **Search Drive for a known template name.** If you know one template by name ("CS Risk Template", "CSM Handover Checklist - TEMPLATE"), find it via Drive search, then look at its `parents`. Often all org templates share a parent.

```bash
# Find a known template, get its parent folder (likely the gallery)
gws drive files list --params '{
  "q": "name='\''CS Risk Template'\'' and trashed=false",
  "supportsAllDrives": true,
  "includeItemsFromAllDrives": true,
  "fields": "files(id,name,parents)"
}'
```

Once you have the gallery folder ID, list everything in it:

```bash
GALLERY_ID="<the folder id>"
gws drive files list --params "{
  \"q\": \"'${GALLERY_ID}' in parents and trashed=false\",
  \"supportsAllDrives\": true,
  \"includeItemsFromAllDrives\": true,
  \"fields\": \"files(id,name,mimeType,modifiedTime,owners(emailAddress))\",
  \"pageSize\": 200
}"
```

That returns the same list the user sees in the "From a template" menu, with file IDs you can pass to `files.copy`.

For large galleries, add `--page-all` to auto-paginate.

## Persistent template-ID lookup

If a workflow uses the same template repeatedly (weekly QBR deck, monthly status doc, etc.), do not re-discover the file ID each time. Cache it: ask the user once, write to `~/.config/gsuite-edit/templates.json`, and read from there going forward.

```json
{
  "kong_cs_idp":                  "1t9zgHv115SywQKA8RZnbMzt4E1ZmM6HsKGxcBwgZIGU",
  "kong_cs_success_plan_draft":   "1UJIy8oyj9r_500n8OzKmiCiYKgwCIpaTLhYmBd6dxXw",
  "kong_dark_slide_theme_2026":   "1BlmOgUbYcw7eBgNhyi3N5masysljt7yvOcU9fxmGPtg",
  "kong_brand_slides_2026":       "1BlmOgUbYcw7eBgNhyi3N5masysljt7yvOcU9fxmGPtg"
}
```

Slides brand-theme entries live in the same JSON. The from-scratch Slides path (see `slides-deep.md`) instructs the agent to look up a brand template ID here and ask the user if none is configured.

### Reading the cache

```bash
CACHE=~/.config/gsuite-edit/templates.json
TEMPLATE_ID=$(jq -r '.kong_cs_idp // empty' "$CACHE")
[[ -n "$TEMPLATE_ID" ]] || {
  echo "no kong_cs_idp entry in $CACHE; ask the user for the file ID and add it" >&2
  exit 1
}
```

### Adding a new entry

If the user gives you a new template ID, ask once whether they want it cached for future runs and write it via `jq`:

```bash
mkdir -p ~/.config/gsuite-edit
CACHE=~/.config/gsuite-edit/templates.json
[[ -f "$CACHE" ]] || echo '{}' > "$CACHE"

KEY="my_new_template"
NEW_ID="1abc..."

jq --arg k "$KEY" --arg v "$NEW_ID" '. + {($k): $v}' "$CACHE" > "$CACHE.tmp" \
  && mv "$CACHE.tmp" "$CACHE"
```

## Picking the right "marker" style for new templates

When the user authors a new template they want to populate programmatically, recommend `{{PLACEHOLDER}}` markers (uppercase, double-curly). They are:

- Unambiguous when scanned with `replaceAllText` (no false matches against real content).
- Easy for a human author to spot in the template.
- Compatible with both Docs and Slides `replaceAllText`.

If the template uses **empty table cells** instead of placeholders (common for HR / IDP / form templates), `replaceAllText` cannot help. Two options:

1. **Read the structure first.** `gws docs documents get --params "{\"documentId\":\"$DOC_ID\"}"` to retrieve the JSON tree, find the table cell offsets, then `insertText` with the right `index`. Fiddly but works.
2. **Accept that the user fills it in by hand.** Copy the template, hand them the URL, let them paste in the prepared content. Often the better trade-off for one-off filings like an annual self-assessment.

Decision rule: how often will this template be filled? Once a year, manual paste. Every week with consistent markers, invest in `replaceAllText` (or get the template author to add `{{placeholders}}`).
