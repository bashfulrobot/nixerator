---
name: gsuite-edit
description: Edit Google Sheets cells and create, copy, or replace Google Docs and Slides from the command line using the `gws` (googleworkspace/cli) tool. Use this skill whenever the user wants to write data into a Google Sheet (e.g. "fill in column X", "batchUpdate these cells", "write self-assessment scores", "update notes/evidence column"), create a Google Doc programmatically (e.g. "make a Google Doc from this markdown / HTML"), replace the body of an existing Google Doc (e.g. "rewrite the IDP doc", "swap out the deck content"), build a Google Slides deck from scratch or from a brand template (e.g. "create a deck for these slides", "build a Slides presentation from this content"), or work from a Workspace template (e.g. "copy this template", "fill in the template placeholders", "clone the IDP template and pre-populate it", "make a copy of the QBR deck template"). Also triggers when the user mentions Google Sheets API, Docs API, Slides API, Drive API, batchUpdate, files.copy, replaceAllText, or asks how to edit Workspace files from a script. Prefer this skill over reaching for a Python SDK when the user just needs a few cell writes, a single doc replacement, a Slides deck, or a template-copy-and-fill flow; `gws` is faster and intuitive. For broader gws usage (gmail, calendar, tasks, chat, auth setup, schema discovery), see the `gws-cli` skill instead.
---

# gsuite-edit: edit Google Sheets, Docs, and Slides via `gws`

Tightly scoped to the four edit operations users reach for most often:

1. Write cells into a Google Sheet.
2. Create a new Google Doc from HTML.
3. Replace the body of an existing Google Doc.
4. Copy a Workspace template and fill its placeholders (Docs or Slides).

For broader Workspace work (sending mail, creating calendar events, listing Drive files, the `+workflow` helpers, one-time auth setup, or any service not in the list above), see the `gws-cli` skill. For Slides decks built from scratch with no template, see `references/slides-deep.md`. For discovering what templates exist in the org, see `references/templates.md`.

## Style rules for generated content

Every piece of content this skill instructs an agent to generate (slide titles, body bullets, speaker notes, doc paragraphs, cell values) must follow these rules:

- **No em dashes (U+2014).** Acceptable alternatives, in order of preference: comma, period, parentheses, colon. En dashes (U+2013) are permitted in numeric ranges (e.g. `pp. 12–18`) but `to` is preferred in prose. Hyphens are unrestricted.
- This rule applies to the skill's own prose as well; edits to this file must not introduce U+2014.

Run `grep -P "\x{2014}"` against any generated artifact before handing it back; the count must be zero.

## Preflight: confirm `gws` is authenticated

Run this once at the top of any workflow. It is cheap and fails loudly if auth is not set up.

```bash
if ! gws auth status 2>/dev/null | grep -q '"storage": "keyring"\|"storage": "file"'; then
  echo "gws is not authenticated. Set it up via the gws-cli skill, then re-run." >&2
  exit 1
fi
```

`gws auth status` exits 0 even when there are no credentials (it just prints `"storage": "none"`), so check the `storage` field. If the preflight fails, do not continue, point the user at the `gws-cli` skill for one-time setup.

## Pattern: write cells in a Sheet (`values.batchUpdate`)

Fastest way to update a Sheet: one call can write to many ranges across multiple tabs.

```bash
SHEET_ID="abc123..."

cat > /tmp/update.json <<'JSON'
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
      "values": [[1, 2, 3, 2, 3]]
    }
  ]
}
JSON

gws sheets spreadsheets values batchUpdate \
  --params "{\"spreadsheetId\":\"${SHEET_ID}\"}" \
  --json @/tmp/update.json
```

Field notes:
- `valueInputOption`: `RAW` writes the value verbatim. Use `USER_ENTERED` if you want Sheets to parse formulas or dates the way the web UI would.
- `range`: A1-notation. Tab names with spaces need quoting inside the range string (`"My Tab!A1:B2"`), not URL-encoding.
- `majorDimension`: `ROWS` (one inner array per row) or `COLUMNS` (one inner array per column). Pick whichever makes the data easier to build.

To find tab names and IDs first:

```bash
gws sheets spreadsheets get \
  --params "{\"spreadsheetId\":\"${SHEET_ID}\",\"fields\":\"sheets(properties(sheetId,title,gridProperties(rowCount,columnCount)))\"}"
```

To read cells back (e.g. to verify a write):

```bash
gws sheets spreadsheets values get \
  --params "{\"spreadsheetId\":\"${SHEET_ID}\",\"range\":\"Tab Name!A1:H30\",\"valueRenderOption\":\"FORMATTED_VALUE\"}"
```

## Pattern: create a new Google Doc from HTML

`gws drive files create` with `--upload` lets Drive convert HTML into a Doc on import. Fastest path from "I have content as HTML" to "Doc exists in My Drive."

```bash
gws drive files create \
  --json '{"name":"My New Doc","mimeType":"application/vnd.google-apps.document"}' \
  --upload /tmp/doc-body.html \
  --upload-content-type "text/html; charset=UTF-8" \
  --params '{"supportsAllDrives":true,"fields":"id,name,webViewLink"}'
```

Returns `{"id": "...", "name": "...", "webViewLink": "..."}`. Hand the user `webViewLink`.

Notes:
- The `mimeType` in the metadata tells Drive to convert HTML to a Doc. Drive supports basic HTML: headings, paragraphs, lists, tables with `border` attributes, bold/italic/code, links.
- For a Sheet, use `application/vnd.google-apps.spreadsheet` and an HTML table or CSV body. For Slides, do **not** use this multipart-import path; the resulting deck is unstyled and fragile. Use the template-copy pattern below, or `references/slides-deep.md` for the from-scratch Slides API path.
- The new file goes to the user's My Drive root by default. To put it in a specific folder, add `"parents": ["<folder_id>"]` to the `--json` metadata.

## Pattern: replace the body of an existing Google Doc

`gws drive files update` with `--upload` re-imports the HTML and replaces the document body. The Doc's `id`, `webViewLink`, sharing settings, and comments all persist; only the body changes.

```bash
DOC_ID="abc123..."

gws drive files update \
  --params "{\"fileId\":\"${DOC_ID}\",\"supportsAllDrives\":true,\"fields\":\"id,modifiedTime\"}" \
  --upload /tmp/doc-body.html \
  --upload-content-type "text/html; charset=UTF-8"
```

When to prefer this over `docs.documents.batchUpdate`:
- Replacing the whole doc body and starting fresh is fine.
- The doc has tables you would otherwise have to navigate with cell indices.
- You have the new content as HTML or Markdown.

When `docs.documents.batchUpdate` (Docs API) is better:
- Inserting a paragraph at a specific location and the existing structure must be preserved.
- Applying small text-substitution edits across a doc (covered in the next section, with `replaceAllText`).
- Modifying a doc with comments or suggestions you must preserve.

The Docs API `batchUpdate` is much more involved (1-indexed character offsets, request-list pattern). Reach for it only when surgical edits matter. For "rewrite the whole thing," the upload above is faster and cleaner.

## Pattern: copy a template and fill it in

The cleanest way to honour a Workspace template (cover slides, branded headers, table layouts you cannot easily replicate with HTML) is to **copy the template** and then **fill in placeholders or specific cells**. Preserves every styling decision the template author made.

### Step 1: Copy the template

```bash
TEMPLATE_ID="abc123..."
NEW_NAME="My Filled Template (2026-05-15)"

NEW=$(gws drive files copy \
  --params "{\"fileId\":\"${TEMPLATE_ID}\",\"supportsAllDrives\":true,\"fields\":\"id,name,webViewLink\"}" \
  --json "{\"name\":\"${NEW_NAME}\"}")

NEW_ID=$(echo "$NEW" | jq -r .id)
NEW_URL=$(echo "$NEW" | jq -r .webViewLink)
```

To put the copy in a specific folder, add `"parents": ["<folder_id>"]` to the `--json` body.

To find templates the user already has access to, or to discover the org template gallery, see `references/templates.md`.

### Step 2: Fill `{{PLACEHOLDER}}` markers

If the template uses `{{placeholder}}` syntax (or any other marker, e.g. `<<name>>`, `[CSM_NAME]`), use `documents.batchUpdate` with `replaceAllText`:

```bash
cat > /tmp/fill.json <<'JSON'
{
  "requests": [
    {"replaceAllText": {"containsText": {"text": "{{CSM_NAME}}", "matchCase": true}, "replaceText": "Dustin Krysak"}},
    {"replaceAllText": {"containsText": {"text": "{{MANAGER}}",  "matchCase": true}, "replaceText": "Mo Ali"}},
    {"replaceAllText": {"containsText": {"text": "{{SCORE}}",    "matchCase": true}, "replaceText": "2.2"}},
    {"replaceAllText": {"containsText": {"text": "{{DATE}}",     "matchCase": true}, "replaceText": "2026-05-15"}}
  ]
}
JSON

gws docs documents batchUpdate \
  --params "{\"documentId\":\"${NEW_ID}\"}" \
  --json @/tmp/fill.json
```

`replaceAllText` works across all text in the doc, including inside table cells, footnotes, and headers. It does not touch images.

For **Slides** templates, the same JSON shape works against the Slides API:

```bash
gws slides presentations batchUpdate \
  --params "{\"presentationId\":\"${NEW_ID}\"}" \
  --json @/tmp/fill.json
```

Slides additionally supports `replaceAllShapesWithImage` (swap a placeholder image with a real one) and `replaceAllShapesWithSheetsChart` (embed a live Sheet chart).

For **Sheets** templates, copy the file, then use the `values.batchUpdate` pattern from the first section.

### When `replaceAllText` is not enough

If the template uses empty table cells instead of `{{placeholders}}` (common for HR / IDP / form templates), see `references/templates.md` for the "marker style" guidance and the structural-read fallback.

## Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| `gws is not authenticated` (from preflight) | No keyring/file credentials | Run the `gws-cli` skill's setup section |
| `Requested entity was not found` on a Drive file | File ID typo, or you do not have access | Verify the file is shared with the gws-authed user; for shared drives include `"supportsAllDrives": true` in `--params` |
| `Requested entity was not found` (404) on a Slides deck via Drive immediately after `presentations.create` | The deck was created via the Slides API and is invisible to the `drive.file` scope | Hand the user `https://docs.google.com/presentation/d/${PRES_ID}/edit`; widen scopes only if you need Drive metadata. Full trap notes: `references/slides-deep.md` |
| `Insufficient Permission` on `files.update` | `drive.file` scope only allows editing files the app created OR explicitly opened | Re-auth with broader Drive scope via `gws-cli` |
| HTML upload landed but tables look broken | Drive's HTML-to-Doc converter is finicky | Add explicit `border="1"` to `<table>` tags; avoid nested tables; use inline `style` attributes sparingly |
| Sheet write succeeded but cells show `#####` | Numbers got written as text | Set `valueInputOption: "USER_ENTERED"` to make Sheets parse them, or write JSON numbers (not strings) in the `values` array |

## When NOT to use this skill

- **Reading large amounts of data**: prefer the Drive MCP (`mcp__claude_ai_Google_Drive__*`) for reads; this skill is for writes.
- **Workspace admin tasks** (user/group/license management, Drive sharing audits): use `gam` instead.
- **Sheet-heavy data workflows with pandas**: prefer `gspread` + a service account.
- **Sending email, creating calendar events, listing Drive metadata, tasks, chat, etc.**: use the `gws-cli` skill (same underlying tool, broader scope).
