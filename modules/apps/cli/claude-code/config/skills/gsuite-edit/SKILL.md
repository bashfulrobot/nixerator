---
name: gsuite-edit
description: Edit Google Sheets cells and create, copy, or replace Google Docs and Slides from the command line using gcloud Application Default Credentials and the Drive / Sheets / Docs / Slides REST APIs. Use this skill whenever the user wants to write data into a Google Sheet (e.g. "fill in column X", "batchUpdate these cells", "write self-assessment scores", "update notes/evidence column"), create a Google Doc programmatically (e.g. "make a Google Doc from this markdown / HTML"), replace the body of an existing Google Doc (e.g. "rewrite the IDP doc", "swap out the deck content"), build a Google Slides deck from scratch or from a brand template (e.g. "create a deck for these slides", "build a Slides presentation from this content"), or work from a Workspace template (e.g. "copy this template", "fill in the template placeholders", "clone the IDP template and pre-populate it", "make a copy of the QBR deck template"). Also triggers when the user mentions Google Sheets API, Docs API, Slides API, Drive API, batchUpdate, files.copy, replaceAllText, gcloud ADC, gspread, or asks how to edit Workspace files from a script. Prefer this skill over reaching for a Python SDK when the user just needs a few cell writes, a single doc replacement, a Slides deck, or a template-copy-and-fill flow; curl + ADC is faster and has no dependencies.
---

# gsuite-edit: edit Google Sheets, Docs, and Slides from the CLI

This skill captures a battle-tested approach for editing Google Workspace files (Sheets, Docs, Slides) programmatically using `gcloud` Application Default Credentials and the Google REST APIs. It is fast, dependency-free (just `curl` + `gcloud`), and works for the common "update some cells", "replace a doc body", or "build a small deck" tasks without needing a Python SDK or a service account.

## Style rules for generated content

Every piece of content this skill instructs an agent to generate (slide titles, body bullets, speaker notes, doc paragraphs, cell values) must follow these rules:

- **No em dashes (U+2014).** Acceptable alternatives, in order of preference: comma, period, parentheses, colon. En dashes (U+2013) are permitted in numeric ranges (e.g. `pp. 12–18`) but `to` is preferred in prose. Hyphens are unrestricted.
- This rule applies to the skill's own prose as well; new edits to this file must not introduce U+2014.

Run `grep -P "\x{2014}"` against any generated artifact before handing it back; the count must be zero.

## When this skill applies

Use whenever the user wants to write to a Google Sheet, Doc, or Slides deck they own (or that they have edit access to) from the command line. Common signals:

- "Write these scores into the sheet"
- "Update column X for rows 12-28"
- "Create a Google Doc with this content"
- "Replace the body of this Doc"
- "Build a Slides deck with these talking points"
- "How do I batchUpdate a Sheet from a shell script?"

**Do not** use this skill if:
- The user has a service account JSON and is comfortable with Python (just use `gspread` or `google-api-python-client`).
- The task is admin-level Workspace administration (use `gam` instead, see Alternatives below).
- The user needs to read large amounts of data (read via the Drive MCP if available; this skill is for writes).

## One-time setup: gcloud ADC with the right scopes

The default `gcloud auth login` does **not** include the Workspace API scopes. Without them, every API call returns 403 `ACCESS_TOKEN_SCOPE_INSUFFICIENT`. Re-auth Application Default Credentials with the explicit scopes:

```bash
gcloud auth application-default login \
  --scopes=openid,email,\
https://www.googleapis.com/auth/cloud-platform,\
https://www.googleapis.com/auth/spreadsheets,\
https://www.googleapis.com/auth/drive.file,\
https://www.googleapis.com/auth/presentations
```

- `spreadsheets`: read/write any sheet the user has access to
- `drive.file`: create new Drive files and modify files the user authored via this app
- `presentations`: read/write Slides decks (required for any Slides API call, including `presentations.create`)
- `cloud-platform`: needed for the quota-project mechanism (see next section)

You can re-run this any time the user adds new scopes later. The `--update-adc` flag on `gcloud auth login` also writes ADC, but using `application-default login` is the cleaner path.

To verify the scopes landed:

```bash
TOKEN=$(gcloud auth application-default print-access-token)
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://oauth2.googleapis.com/tokeninfo" | grep scope
```

Send the token as an `Authorization: Bearer` header rather than as the `?access_token=...` query parameter the older Google docs sometimes show. The header form keeps the token out of shell history, proxy access logs, HAR captures, and any `set -x` trace that runs while debugging.

You should see `spreadsheets`, `drive.file`, and `presentations` in the output. For a structured check that exits non-zero on missing scopes and prints a ready-to-paste re-auth command, use the `gsuite_check_scopes` helper documented in the Quick reference section.

## Preflight: verify ADC scopes before the first API call

Always run a scope preflight before the first API call in a workflow. Calling `presentations.create` (or any other Workspace endpoint) with a token that is missing the required scope returns a 403 that is easy to misdiagnose as a permissions or quota issue.

The tokeninfo endpoint returns the active token's scopes as a single space-separated string:

```bash
TOKEN=$(gcloud auth application-default print-access-token)
curl -sS -H "Authorization: Bearer $TOKEN" \
  "https://oauth2.googleapis.com/tokeninfo"
```

Sample response (truncated):

```json
{
  "azp": "...",
  "scope": "openid https://www.googleapis.com/auth/cloud-platform https://www.googleapis.com/auth/spreadsheets",
  "expires_in": 3599,
  "email": "user@example.com"
}
```

A reliable scope check splits the `scope` field on whitespace and looks for exact matches (substring matching trips up because `drive.file` is a prefix of `drive.file.something` should it ever appear). The `gsuite_check_scopes` helper in the Quick reference section does this for you and prints a ready-to-paste `gcloud auth application-default login --scopes=...` command if any required scope is missing.

For a Slides workflow:

```bash
gsuite_check_scopes \
  https://www.googleapis.com/auth/drive.file \
  https://www.googleapis.com/auth/presentations
```

If it exits non-zero, copy the re-auth command it prints, run it, then re-run the preflight. Do not proceed to the API calls until the preflight passes.

## The quota-project header pattern

User-credential ADC tokens require an `X-Goog-User-Project` header on every Workspace API call. Without it you get:

```
"Your application is authenticating by using local Application Default Credentials.
 The sheets.googleapis.com API requires a quota project, which is not set by default."
```

Fix by sending the user's active gcloud project as `X-Goog-User-Project`:

```bash
QUOTA_PROJECT=$(gcloud config get-value project)
curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  https://sheets.googleapis.com/v4/spreadsheets/...
```

The project doesn't need to be related to the sheet/doc owner; it just needs to be a project the user has access to. Sheets / Docs / Slides / Drive APIs must be enabled in that project (they are by default for any GCP project that was created via the console).

## Pattern: write cells in a Sheet (values.batchUpdate)

Use `spreadsheets.values:batchUpdate` to write one or more ranges in a single call. This is by far the fastest way to update a Sheet, because one API hit can write to many ranges across multiple tabs.

The request body is a JSON document. The most common shape is:

```json
{
  "valueInputOption": "RAW",
  "data": [
    {
      "range": "Tab Name!H12:H28",
      "majorDimension": "ROWS",
      "values": [
        ["row 12 value"],
        ["row 13 value"],
        ["row 14 value"]
      ]
    },
    {
      "range": "Tab Name!D12:D28",
      "majorDimension": "COLUMNS",
      "values": [[1, 2, 3, 2, 3, ...]]
    }
  ]
}
```

Field notes:
- `valueInputOption`: `RAW` writes the value verbatim. Use `USER_ENTERED` if you want Sheets to parse formulas or dates the way the web UI would.
- `range`: A1-notation, including the tab name with quotes if the tab name has spaces (`"My Tab!A1:B2"`).
- `majorDimension`: `ROWS` (one inner array per row) or `COLUMNS` (one inner array per column). Pick whichever makes the data easier to build.

Posting it:

```bash
SHEET_ID="abc123..."
curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d @/tmp/update.json \
  "https://sheets.googleapis.com/v4/spreadsheets/${SHEET_ID}/values:batchUpdate"
```

To find the tab names and IDs first:

```bash
curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  "https://sheets.googleapis.com/v4/spreadsheets/${SHEET_ID}?fields=sheets(properties(sheetId,title,gridProperties(rowCount,columnCount)))"
```

To read cells back (e.g. to verify a write):

```bash
curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  "https://sheets.googleapis.com/v4/spreadsheets/${SHEET_ID}/values/Tab%20Name!A1:H30?valueRenderOption=FORMATTED_VALUE"
```

URL-encode tab names with spaces (`%20`).

## Pattern: create a new Google Doc from HTML

Drive supports a multipart upload that creates a Doc by converting an HTML body. This is the fastest way to go from "I have content as HTML" to "Google Doc exists in My Drive."

```bash
BOUNDARY="===boundary==="
META='{"name":"My New Doc","mimeType":"application/vnd.google-apps.document"}'

# Build the multipart body
{
  printf -- '--%s\r\n' "$BOUNDARY"
  printf 'Content-Type: application/json; charset=UTF-8\r\n\r\n'
  printf '%s\r\n' "$META"
  printf -- '--%s\r\n' "$BOUNDARY"
  printf 'Content-Type: text/html; charset=UTF-8\r\n\r\n'
  cat /tmp/doc-body.html
  printf '\r\n--%s--\r\n' "$BOUNDARY"
} > /tmp/multipart.bin

curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: multipart/related; boundary=$BOUNDARY" \
  --data-binary @/tmp/multipart.bin \
  "https://www.googleapis.com/upload/drive/v3/files?uploadType=multipart&supportsAllDrives=true&fields=id,name,webViewLink"
```

Returns `{"id": "...", "name": "...", "webViewLink": "..."}`. Hand the user `webViewLink`.

Notes:
- `mimeType: application/vnd.google-apps.document` tells Drive to convert the HTML to a Doc on import. Drive supports basic HTML: headings, paragraphs, lists, tables with `border` attributes, bold/italic/code, links.
- For a Sheet, use `application/vnd.google-apps.spreadsheet` and an HTML table or CSV body. For Slides, do not use this multipart-import path; the resulting deck is unstyled and fragile. Use the Slides-API pattern documented below instead.
- `supportsAllDrives=true` lets you target shared drives.
- The new file goes to the user's My Drive root by default. To put it in a specific folder, add `"parents": ["<folder_id>"]` to the metadata JSON.

## Pattern: create a Google Slides deck from scratch

For customer-facing Slides decks the brand-template path is almost always the right starting point; jump to "Pattern: copy a template and fill it in" if you have a template ID. The from-scratch path documented here produces an unstyled deck using Google's default theme, which is rarely what you want for branded work.

### Theming: prefer copying a brand template

Slides theming is applied by copying a brand template, not by configuring the deck after creation. The Slides API has no programmatic way to install a theme on a presentation; the theme is baked into the template file. The flow is:

1. Pick a brand template file ID (cached via the "Persistent template-ID lookup" pattern earlier in this skill, e.g. `~/.config/gsuite-edit/templates.json`).
2. `files.copy` the template to create a new branded deck (see "Pattern: copy a template and fill it in" for the request shape).
3. Populate the resulting deck via the Slides API. Slides supports `replaceAllText` too, so if the template uses `{{placeholders}}` the same Docs-style fill pattern works.

Store the brand template's file ID in the template cache:

```json
{
  "kong_brand_slides_2026": "1BlmOgUbYcw7eBgNhyi3N5masysljt7yvOcU9fxmGPtg"
}
```

**If no brand template ID is configured for a Slides build, ask the user for one** before emitting an unstyled deck. Silently producing a deck in Google's default theme is almost always wrong for the user's intent. Acceptable answers from the user include: "use this template ID", "save this ID as `<key>` in the cache and use it", or "no theme, default is fine for this one".

The rest of this section covers the from-scratch path, which is the right tool for: scratch prototypes, internal-only decks where theming doesn't matter, or building a deck that will be hand-styled afterward.

### Step 1: Create the empty presentation

```bash
TOKEN=$(gcloud auth application-default print-access-token)
QUOTA_PROJECT=$(gcloud config get-value project)

RESP=$(curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{"title": "My Deck"}' \
  "https://slides.googleapis.com/v1/presentations")

PRES_ID=$(echo "$RESP" | python3 -c "import json,sys; print(json.load(sys.stdin).get('presentationId',''))")
[[ -n "$PRES_ID" ]] || { echo "presentations.create failed:" >&2; echo "$RESP" >&2; exit 1; }

# Capture the default first slide's objectId. presentations.create returns a
# response whose slides[0] is a blank cover slide with the TITLE layout; the
# Step 2 batchUpdate below deletes it so the deck ends up with exactly the
# slides we explicitly add. If you want that default slide to be your cover,
# capture its objectId here and `insertText` into its existing placeholders
# instead of deleting it.
DEFAULT_SLIDE_ID=$(echo "$RESP" | python3 -c "import json,sys; pres=json.load(sys.stdin); print(pres.get('slides',[{}])[0].get('objectId',''))")
```

`presentations.create` returns the full presentation object. Its `slides[0]` is a default cover slide with the `TITLE` layout. The from-scratch example below deletes that default slide in the same `batchUpdate` that creates the real content slide, so the resulting deck contains only the slides this code adds. Subsequent slides beyond the first are added via additional `createSlide` requests in the same or later batch.

### Step 2: Add a slide with deterministic placeholder IDs

`placeholderIdMappings` on a `createSlide` request lets the caller assign deterministic object IDs to the layout's TITLE and BODY placeholders inside the same `batchUpdate`, which avoids a fetch-then-update round trip. Use it whenever you know which placeholder types you want to populate.

Write the batch to `/tmp/slide-1.json`; the `${DEFAULT_SLIDE_ID}` placeholder is substituted from Step 1.

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
          {"layoutPlaceholder": {"type": "BODY", "index": 0}, "objectId": "slide_1_body"}
        ]
      }
    },
    {"insertText": {"objectId": "slide_1_title", "text": "Strategic objectives"}},
    {"insertText": {"objectId": "slide_1_body", "text": "Reduce gateway p99 latency by 25%\\nShip Konnect data plane in EU\\nAdopt OpenTelemetry across all services"}},
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
```

`batchUpdate` applies requests atomically and in order, so the `deleteObject` runs before `createSlide` and the deck ends with exactly one content slide. If you want to keep the default cover slide and add a content slide after it, drop the `deleteObject` request and the deck will have two slides.

Post the batch:

```bash
curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d @/tmp/slide-1.json \
  "https://slides.googleapis.com/v1/presentations/${PRES_ID}:batchUpdate"
```

`createParagraphBullets` with `BULLET_DISC_CIRCLE_SQUARE` converts each newline-separated line in the body shape into a real bulleted list with nested-level styling. Without this request, the body text shows up as plain lines, not bullets.

Layout choice cheat sheet (`predefinedLayout`):

- `TITLE`: cover slide (title plus subtitle placeholder).
- `TITLE_AND_BODY`: standard content slide (title plus body).
- `SECTION_HEADER`: full-bleed section divider (large centred title).
- `BLANK`: empty slide, useful when you intend to position shapes by hand later.

The `index` field inside `layoutPlaceholder` is zero-based. `TITLE_AND_BODY` has one TITLE placeholder (index 0) and one BODY placeholder (index 0); `TITLE` has one TITLE placeholder and one SUBTITLE placeholder, each at index 0. For the full enum see the Slides API reference for `PredefinedLayout`.

### Step 3: Speaker notes (second round-trip required)

The notes page for a slide is created after the slide itself is added, and its object ID is not addressable via `placeholderIdMappings`. To populate speaker notes:

1. `GET /v1/presentations/${PRES_ID}` to fetch the current presentation tree.
2. For each slide, walk to `slideProperties.notesPage.notesProperties.speakerNotesObjectId`.
3. Send a second `batchUpdate` with `insertText` requests targeting those object IDs.

```bash
NOTES_OBJ=$(curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  "https://slides.googleapis.com/v1/presentations/${PRES_ID}" \
  | python3 -c '
import json, sys
pres = json.load(sys.stdin)
for s in pres["slides"]:
    if s["objectId"] == "slide_1":
        print(s["slideProperties"]["notesPage"]["notesProperties"]["speakerNotesObjectId"])
        sys.exit(0)
sys.exit("slide_1 not found in presentation")
')
[[ -n "$NOTES_OBJ" ]] || { echo "could not locate speakerNotesObjectId for slide_1" >&2; exit 1; }

curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d "{\"requests\":[{\"insertText\":{\"objectId\":\"${NOTES_OBJ}\",\"text\":\"Open with the latency win, then pivot to Konnect EU.\"}}]}" \
  "https://slides.googleapis.com/v1/presentations/${PRES_ID}:batchUpdate"
```

The `sys.exit("...")` plus `[[ -n "$NOTES_OBJ" ]]` guard prevents a silent no-op (e.g. typo in the slide objectId, or slide deleted between Steps 2 and 3). Without it, an empty `NOTES_OBJ` would post `{"objectId":""}` and Slides would return a confusing API error rather than a clear "slide not found" diagnostic.

If the workflow adds many slides, batch the `speakerNotesObjectId` discovery into a single `presentations.get`, then build one `batchUpdate` with one `insertText` per slide. Apply the same guard pattern to each slide ID, since one missing slide should fail the whole batch loudly rather than silently dropping a notes update.

### Step 4: Hand back the URL

A presentation created via the Slides API is **not visible to the `drive.file` scope**. Calling `https://www.googleapis.com/drive/v3/files/${PRES_ID}` from a `drive.file`-scoped token returns 404, because `drive.file` only sees files the app created via Drive itself. The Slides API created the presentation directly, not through Drive.

Two consequences:

1. Use the deterministic Slides URL pattern to hand the deck back to the user. No Drive call required:

   ```
   https://docs.google.com/presentation/d/${PRES_ID}/edit
   ```

2. Widen to the full `https://www.googleapis.com/auth/drive` scope only when the workflow actually needs Drive metadata: parent folder, `modifiedTime`, sharing settings, or `files.update` to move or rename the deck. If the deck stays in the user's My Drive root and just needs to be opened, the `drive.file` scope is sufficient and no Drive call is needed.

## Background: what "New from template" actually is

When a Workspace user opens Docs/Sheets/Slides and clicks **File → New → From a template gallery**, they see two sections:

1. **General templates**: Google-provided defaults (Resume, Project Tracker, Meeting Notes, etc.). These are real Drive files owned by Google with stable, publicly-known file IDs.
2. **Your org's templates**: admin-published templates specific to the Workspace tenant. The admin configures these in Admin Console → Apps → Google Workspace → Drive and Docs → Templates. Behind the scenes, this points at a Drive folder. Anything in that folder shows up in the gallery.

**There is no dedicated `templateGallery` REST endpoint.** The Drive UI is rendering a normal Drive folder. Programmatic access is just `files.list` against the right folder, plus `files.copy` to clone an entry.

### What this means for the skill

- If the user knows the file ID of a template (because they opened it once or got a link), `files.copy` works immediately, with no special handling needed.
- If the user wants to discover what templates exist, you need the **template gallery folder ID** for their org. Ask the user. If they don't know, they can ask their Workspace admin, or pull it from any template's `parents` field after copying one from the UI once.
- For Google-provided general templates, the easiest path is to copy one through the UI once, then capture the resulting copy's `parents`/`originalFilename`/template metadata to identify the source.

### Finding the org template gallery folder ID

If the user wants to list all org templates programmatically, get the gallery folder ID first. Three ways to find it:

1. **Ask the Workspace admin.** Fastest. The admin configured it.
2. **Inspect a template URL.** Open the Workspace template gallery in the browser, click any template to preview it, copy the URL. The path will include the document's file ID. Look up that file's `parents` field via Drive API to get the gallery folder ID.
3. **Search Drive for known template names.** If you know one template by name ("CS Risk Template", "CSM Handover Checklist - TEMPLATE"), find it via Drive search, then look at its `parents`. Often all org templates share a parent.

```bash
# Find a known template, get its parent folder (likely the gallery)
curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  "https://www.googleapis.com/drive/v3/files?q=name='CS+Risk+Template'+and+trashed=false&supportsAllDrives=true&includeItemsFromAllDrives=true&fields=files(id,name,parents)"
```

Once you have the gallery folder ID, list everything in it:

```bash
GALLERY_ID="<the folder id>"
curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  "https://www.googleapis.com/drive/v3/files?q='${GALLERY_ID}'+in+parents+and+trashed=false&supportsAllDrives=true&includeItemsFromAllDrives=true&fields=files(id,name,mimeType,modifiedTime,owners(emailAddress))&pageSize=200"
```

That returns the same list the user sees in the "From a template" menu, with file IDs you can pass to `files.copy`.

### Persistent template-ID lookup

If a workflow uses the same template repeatedly (e.g. a weekly QBR deck), don't re-discover the file ID each time. Cache it: ask the user once, write to a config file alongside the skill (e.g. `~/.config/gsuite-edit/templates.json`), and read from there going forward.

```json
{
  "kong_cs_idp": "1t9zgHv115SywQKA8RZnbMzt4E1ZmM6HsKGxcBwgZIGU",
  "kong_cs_success_plan_draft": "1UJIy8oyj9r_500n8OzKmiCiYKgwCIpaTLhYmBd6dxXw",
  "kong_dark_slide_theme_2026": "1BlmOgUbYcw7eBgNhyi3N5masysljt7yvOcU9fxmGPtg",
  "kong_brand_slides_2026": "1BlmOgUbYcw7eBgNhyi3N5masysljt7yvOcU9fxmGPtg"
}
```

Slides theming entries live in the same JSON. The "Pattern: create a Google Slides deck from scratch" section above tells the agent to look up a brand template ID here and ask the user if none is configured.

## Pattern: copy a template and fill it in

The cleanest way to honour a Workspace-provided template (cover slides, branded headers, table layouts you can't easily replicate with HTML) is to **copy the template** and then **fill in placeholders or specific cells**. This preserves every styling decision the template author made.

### Step 1: Copy the template

```bash
TEMPLATE_ID="abc123..."
NEW_NAME="My Filled Template (2026-05-15)"

curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d "{\"name\": \"$NEW_NAME\"}" \
  "https://www.googleapis.com/drive/v3/files/${TEMPLATE_ID}/copy?supportsAllDrives=true&fields=id,name,webViewLink"
```

Returns `{"id": "...", "name": "...", "webViewLink": "..."}`. Hand `webViewLink` to the user, or capture `id` to continue editing.

To put the copy in a specific folder, add `"parents": ["<folder_id>"]` to the JSON body.

To find templates the user can access:

```bash
# Search by title pattern (Drive q syntax)
curl -sS \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  "https://www.googleapis.com/drive/v3/files?q=name+contains+'IDP+Template'+and+mimeType='application/vnd.google-apps.document'&supportsAllDrives=true&includeItemsFromAllDrives=true&fields=files(id,name,parents,modifiedTime)"
```

Workspace template galleries (the "From a template" picker in Docs/Sheets/Slides) are stored as regular Drive files under specific shared drives. If your org has a template gallery, search for the doc by title.

### Step 2: Fill in placeholders (Docs API `replaceAllText`)

If the template uses `{{placeholder}}` syntax (or any other marker, e.g. `<<name>>`, `[CSM_NAME]`), use `documents.batchUpdate` with `replaceAllText` requests:

```bash
NEW_DOC_ID="<id returned from copy>"

cat > /tmp/fill.json <<'JSON'
{
  "requests": [
    {"replaceAllText": {"containsText": {"text": "{{CSM_NAME}}", "matchCase": true}, "replaceText": "Dustin Krysak"}},
    {"replaceAllText": {"containsText": {"text": "{{MANAGER}}", "matchCase": true}, "replaceText": "Mo Ali"}},
    {"replaceAllText": {"containsText": {"text": "{{SCORE}}", "matchCase": true}, "replaceText": "2.2"}},
    {"replaceAllText": {"containsText": {"text": "{{DATE}}", "matchCase": true}, "replaceText": "2026-05-15"}}
  ]
}
JSON

curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d @/tmp/fill.json \
  "https://docs.googleapis.com/v1/documents/${NEW_DOC_ID}:batchUpdate"
```

`replaceAllText` works across all text in the doc, including inside table cells, footnotes, and headers. It does not work on images.

### Step 3: Other useful batchUpdate requests

The Docs API supports many request types in the same batchUpdate call. The ones worth knowing for templates:

- `replaceAllText`: substitute marker strings (most common for templates).
- `insertText`: insert text at a specific 1-indexed character offset. Use only when you already know the offset; getting it usually requires reading the doc structure first via `documents.get`.
- `insertTableRow` / `insertTableColumn`: add rows/columns to existing tables. Useful when the template has a fixed-row table you need to extend (e.g. an Action Plan table with 5 rows but you have 7 items).
- `deleteContentRange`: remove a range. Useful for stripping placeholder boilerplate.
- `updateTextStyle` / `updateParagraphStyle`: change formatting on a range. Rare for templates since the template already has the styles you want.

For Slides templates (PPTX-style), the Slides API has the same `replaceAllText` plus `replaceAllShapesWithImage` (swap a placeholder image with a real one) and `replaceAllShapesWithSheetsChart` (embed a live Sheet chart). Endpoint is `https://slides.googleapis.com/v1/presentations/${PRES_ID}:batchUpdate`.

For Sheets templates, just copy the file and then use the `values:batchUpdate` pattern from the Sheets section above to fill in cells.

### When `replaceAllText` is not enough

If the template uses **empty table cells** instead of `{{placeholders}}` (which is common for Workspace IDP / form templates), `replaceAllText` won't help, because there's no marker to find. Two options:

1. **Read the structure first.** Call `documents.get` to retrieve the doc as a JSON tree, find the table cell offsets you need, then use `insertText` with the right `index` value. This is fiddly but works.
2. **Accept that the user fills it in by hand.** Copy the template, hand them the URL, and let them paste in the prepared content. This is often the better trade-off for one-off filings like an annual self-assessment.

The decision is: how often will this template be filled? Once a year, manual paste. Every week with consistent placeholder names, invest in `replaceAllText` (or get the template author to add `{{placeholders}}`).

### End-to-end example: clone IDP template, fill placeholders, hand back URL

```bash
TOKEN=$(gcloud auth application-default print-access-token)
QUOTA_PROJECT=$(gcloud config get-value project)
TEMPLATE_ID="1WUqjn943JJ6YP63oIg1BqF4mIDy6qr35luz7_jLjv0g"

# 1. Copy
NEW=$(curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{"name": "FY27 IDP, Dustin Krysak"}' \
  "https://www.googleapis.com/drive/v3/files/${TEMPLATE_ID}/copy?fields=id,webViewLink")

NEW_ID=$(echo "$NEW" | python3 -c "import json,sys; print(json.load(sys.stdin)['id'])")
NEW_URL=$(echo "$NEW" | python3 -c "import json,sys; print(json.load(sys.stdin)['webViewLink'])")

# 2. Fill placeholders (if template uses them)
curl -sS -X POST \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: application/json" \
  -d '{"requests":[{"replaceAllText":{"containsText":{"text":"{{CSM_NAME}}","matchCase":true},"replaceText":"Dustin Krysak"}}]}' \
  "https://docs.googleapis.com/v1/documents/${NEW_ID}:batchUpdate" > /dev/null

# 3. Tell user
echo "New doc: $NEW_URL"
```

## Pattern: replace the body of an existing Google Doc

The cleanest way to swap out a Doc's entire body is a Drive media PATCH with new HTML. Drive re-imports the HTML and replaces the content. The Doc's `id`, `webViewLink`, sharing settings, and comments all persist; only the body changes.

```bash
DOC_ID="abc123..."
curl -sS -X PATCH \
  -H "Authorization: Bearer $TOKEN" \
  -H "X-Goog-User-Project: $QUOTA_PROJECT" \
  -H "Content-Type: text/html; charset=UTF-8" \
  --data-binary @/tmp/doc-body.html \
  "https://www.googleapis.com/upload/drive/v3/files/${DOC_ID}?uploadType=media&supportsAllDrives=true&fields=id,modifiedTime"
```

When to prefer this over `docs.documents:batchUpdate`:
- You're replacing the whole doc body and starting fresh is fine.
- The doc has tables you'd otherwise have to navigate with cell indices.
- You have the new content as HTML or Markdown.

When `docs.documents:batchUpdate` (Docs API) is better:
- You're inserting a paragraph at a specific location and need the existing structure preserved.
- You're applying small text-substitution edits across a doc.
- You need to modify a doc with comments or suggestions you must preserve.

The Docs API batchUpdate is much more involved; it uses 1-indexed character offsets and a request-list pattern. Reach for it only when surgical edits matter. For "rewrite the whole thing," the media PATCH above is faster and cleaner.

## Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| `ACCESS_TOKEN_SCOPE_INSUFFICIENT` | gcloud token lacks sheets / drive / presentations scope | Run the Preflight section's `gsuite_check_scopes`, then re-auth with `gcloud auth application-default login --scopes=...` (see Setup) |
| `Method doesn't allow unregistered callers` / `quota project not set` | Missing `X-Goog-User-Project` header on a user-credential call | Add `-H "X-Goog-User-Project: $(gcloud config get-value project)"` |
| `Requested entity was not found` on a Drive file | File ID typo or you don't have access | Verify the file is shared with the gcloud-authed user; for shared drives add `supportsAllDrives=true` |
| `Requested entity was not found` (404) on a Slides presentation accessed via Drive (e.g. `drive/v3/files/${PRES_ID}` returns 404 immediately after `presentations.create` succeeds) | The deck was created via the Slides API and is invisible to the `drive.file` scope (`drive.file` only sees files the app created via Drive itself) | Hand the user the deterministic URL `https://docs.google.com/presentation/d/${PRES_ID}/edit` instead of calling Drive; widen to full `drive` scope only when you actually need Drive metadata (`modifiedTime`, `parents`, sharing) |
| `Insufficient Permission` on `files.update` | `drive.file` scope only allows editing files the app created OR explicitly opened. Pre-existing Docs not authored via your token may need a broader scope | Re-auth with `https://www.googleapis.com/auth/drive` (full Drive access) if you need to edit arbitrary docs |
| HTML upload landed but tables look broken | Drive's HTML to Doc converter is finicky | Add explicit `border="1"` to `<table>` tags; avoid nested tables; avoid CSS, and use inline `style` attributes sparingly |
| Sheet write succeeded but cells show `#####` | Numbers got written as text | Set `valueInputOption: "USER_ENTERED"` to make Sheets parse them, or write JSON numbers (not strings) in the `values` array |

## Alternatives (when not to use this skill)

| Tool | What it's good at | When to choose it |
|---|---|---|
| **`gam` (Google Apps Manager)** | Workspace admin: user/group/license management, Drive sharing audits, bulk operations on Drive files | When you're administering a Workspace tenant, not just editing one file |
| **`gspread` (Python)** | Sheet-heavy workflows with multiple reads/writes, pandas integration | When you'd rather write Python than bash, especially with data analysis afterward |
| **`google-api-python-client`** | Full coverage of every Google API, programmatic flexibility | When you need APIs this skill doesn't cover (Calendar, Gmail, BigQuery, etc.) |
| **Drive MCP (`mcp__claude_ai_Google_Drive__*`)** | Reading file metadata, file content, listing recent files | When you only need to read, not write. The MCP doesn't have edit tools. |
| **Google Apps Script** | Logic that runs inside Google's environment with no auth overhead | When the task is event-driven (form submission, on-edit) or runs on a schedule via Workspace |
| **`clasp`** | Managing Google Apps Script projects from CLI | Companion to Apps Script for push/pull of script files |

For 90% of "I just need to write some cells / create a doc / replace a doc body / build a small Slides deck" tasks from a shell, the curl + ADC pattern in this skill is the simplest path.

## Quick reference: minimal working script

A drop-in shell function for the common operations:

```bash
gsuite_token() {
  gcloud auth application-default print-access-token
}

gsuite_quota_project() {
  gcloud config get-value project 2>/dev/null
}

gsuite_curl() {
  curl -sS \
    -H "Authorization: Bearer $(gsuite_token)" \
    -H "X-Goog-User-Project: $(gsuite_quota_project)" \
    "$@"
}

# gsuite_check_scopes <scope> [<scope>...]
#   Exits 0 if every required scope is granted on the current ADC token.
#   Exits 1 and prints a ready-to-paste re-auth command if any scope is missing.
#   Exits 2 on usage error.
#
# The re-auth command preserves every scope currently granted to the ADC token
# AND unions in the required scopes. This matters because
# `gcloud auth application-default login --scopes=...` replaces ADC scopes
# wholesale (it does not additively merge), so a naive command that lists only
# the missing scopes would silently drop unrelated scopes the user already had.
gsuite_check_scopes() {
  if [[ $# -eq 0 ]]; then
    echo "usage: gsuite_check_scopes <scope> [<scope>...]" >&2
    return 2
  fi

  local granted
  granted=$(curl -sS -H "Authorization: Bearer $(gsuite_token)" \
    "https://oauth2.googleapis.com/tokeninfo" \
    | python3 -c 'import json,sys; print(json.load(sys.stdin).get("scope",""))')

  local missing=()
  local scope
  for scope in "$@"; do
    case " $granted " in
      *" $scope "*) ;;
      *) missing+=("$scope") ;;
    esac
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo "missing scopes:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    echo "" >&2

    # Build the re-auth scope list as the union of currently-granted scopes
    # and required scopes, deduplicated, comma-separated. Split $granted on
    # whitespace with `tr` rather than relying on unquoted word-splitting so
    # any unexpected glob character in a scope string (e.g. `*`) cannot
    # trigger pathname expansion against the caller's cwd.
    local all_list
    all_list=$(
      {
        printf '%s\n' "$granted" | tr ' \t' '\n\n'
        printf '%s\n' "$@"
      } | awk 'NF && !seen[$0]++' | paste -sd,
    )

    echo "re-auth with:" >&2
    echo "  gcloud auth application-default login --scopes=$all_list" >&2
    return 1
  fi
}

# usage:
# gsuite_curl "https://sheets.googleapis.com/v4/spreadsheets/$SHEET_ID?fields=sheets.properties"
# gsuite_curl -X POST -H "Content-Type: application/json" -d @body.json "https://sheets.googleapis.com/v4/spreadsheets/$SHEET_ID/values:batchUpdate"
# gsuite_check_scopes https://www.googleapis.com/auth/presentations https://www.googleapis.com/auth/drive.file
```

Drop into `~/.bashrc` or a project script and the API calls become one-liners.
