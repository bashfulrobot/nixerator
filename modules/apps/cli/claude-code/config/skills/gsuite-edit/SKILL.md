---
name: gsuite-edit
description: Edit Google Sheets cells and create, copy, or replace Google Docs and Slides from the command line using the `gws` (googleworkspace/cli) tool. Use this skill whenever the user wants to write data into a Google Sheet (e.g. "fill in column X", "batchUpdate these cells", "write self-assessment scores", "update notes/evidence column"), create a Google Doc programmatically (e.g. "make a Google Doc from this markdown / HTML"), replace the body of an existing Google Doc (e.g. "rewrite the IDP doc", "swap out the deck content"), build a Google Slides deck from scratch or from a brand template (e.g. "create a deck for these slides", "build a Slides presentation from this content"), or work from a Workspace template (e.g. "copy this template", "fill in the template placeholders", "clone the IDP template and pre-populate it", "make a copy of the QBR deck template"). Also triggers when the user mentions Google Sheets API, Docs API, Slides API, Drive API, batchUpdate, files.copy, replaceAllText, or asks how to edit Workspace files from a script. Prefer this skill over reaching for a Python SDK when the user just needs a few cell writes, a single doc replacement, a Slides deck, or a template-copy-and-fill flow; `gws` is faster and intuitive. For broader gws usage (gmail, calendar, tasks, chat, auth setup, schema discovery), see the `gws-cli` skill instead.
---

# gsuite-edit: edit Google Sheets, Docs, and Slides via `gws`

Tightly scoped to the five edit operations users reach for most often:

1. Write cells into a Google Sheet.
2. Create a new Google Doc from HTML.
3. Replace the body of an existing Google Doc.
4. Copy a Workspace template and fill its placeholders (Docs or Slides).
5. Clone a branded doc and rebuild its body while keeping the theme (logo, fonts, colors).

For broader Workspace work (sending mail, creating calendar events, listing Drive files, the `+workflow` helpers, one-time auth setup, or any service not in the list above), see the `gws-cli` skill. For Slides decks built from scratch with no template, see `references/slides-deep.md`. For discovering what templates exist in the org, see `references/templates.md`.

## Style rules for generated content

Every piece of content this skill instructs an agent to generate (slide titles, body bullets, speaker notes, doc paragraphs, cell values) must follow these rules:

- **No em dashes (U+2014).** Acceptable alternatives, in order of preference: comma, period, parentheses, colon. En dashes (U+2013) are permitted in numeric ranges (e.g. `pp. 12–18`) but `to` is preferred in prose. Hyphens are unrestricted.
- This rule applies to the skill's own prose as well; edits to this file must not introduce U+2014.

Run `grep -P "\x{2014}"` against any generated artifact before handing it back; the count must be zero.

## Preflight: confirm `gws` is authenticated

Run this once at the top of any workflow. It is cheap and fails loudly if auth is not set up.

```bash
if ! gws auth status 2>/dev/null | grep -q '"token_valid": true'; then
  echo "gws is not authenticated. Set it up via the gws-cli skill, then re-run." >&2
  exit 1
fi
```

`gws auth status` exits 0 even when there are no credentials, so check a field in its JSON. `token_valid` is the reliable signal. Do NOT key off `storage` alone: it can be `keyring`, `file`, or `encrypted`, and an `encrypted` keyring store is a normal authenticated state. A `keyring|file`-only grep gives a false "not authenticated" (verified: a working auth reported `"storage": "encrypted"` with `"token_valid": true`). If the preflight fails, do not continue, point the user at the `gws-cli` skill for one-time setup.

## `gws` invocation gotchas (verified)

Two `gws` flag behaviors bite every pattern below. They are quirks of the CLI build, not the Google APIs:

- **`--json` does not accept `@file` in this build.** `--json @/tmp/x.json` fails with `Invalid --json body: expected value at line 1 column 1` (absolute and relative paths both fail). Pass JSON inline: `--json '{"...":"..."}'`. For a large body held in a file, splice it in with command substitution: `--json "$(cat /tmp/x.json)"`. Every `--json` example below uses one of these two forms.
- **`--upload` paths must be inside the current working directory.** `--upload /tmp/body.html` fails with `resolves to '/tmp/body.html' which is outside the current directory`. Write or copy the upload file into the cwd first, then reference it relatively (`--upload ./body.html`).

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
  --json "$(cat /tmp/update.json)"
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
# the upload file must live in the cwd (see invocation gotchas)
gws drive files create \
  --json '{"name":"My New Doc","mimeType":"application/vnd.google-apps.document"}' \
  --upload ./doc-body.html \
  --upload-content-type "text/html; charset=UTF-8" \
  --params '{"supportsAllDrives":true,"fields":"id,name,webViewLink"}'
```

Returns `{"id": "...", "name": "...", "webViewLink": "..."}`. Hand the user `webViewLink`.

Notes:
- The `mimeType` in the metadata tells Drive to convert HTML to a Doc. Drive supports basic HTML: headings, paragraphs, lists, tables with `border` attributes, bold/italic/code, links.
- For a Sheet, use `application/vnd.google-apps.spreadsheet` and an HTML table or CSV body. For Slides, do **not** use this multipart-import path; the resulting deck is unstyled and fragile. Use the template-copy pattern below, or `references/slides-deep.md` for the from-scratch Slides API path.
- The new file goes to the user's My Drive root by default. To put it in a specific folder, add `"parents": ["<folder_id>"]` to the `--json` metadata.
- **The created doc has NO theme or branding.** Drive's HTML import applies Google's default named styles (Arial body, plain headings); it cannot carry a brand template's fonts, colors, or logo. If the output must match a branded template, do not use this path. Clone the template and rebuild the body instead (see "Pattern: clone a themed doc and rebuild its body").

## Pattern: replace the body of an existing Google Doc

`gws drive files update` with `--upload` re-imports the HTML. The Doc's `id`, `webViewLink`, and sharing settings persist, but the re-import is a **full conversion**, not a body-only swap.

```bash
DOC_ID="abc123..."

# the upload file must live in the cwd (see invocation gotchas)
gws drive files update \
  --params "{\"fileId\":\"${DOC_ID}\",\"supportsAllDrives\":true,\"fields\":\"id,modifiedTime\"}" \
  --upload ./doc-body.html \
  --upload-content-type "text/html; charset=UTF-8"
```

> **Theme warning (verified).** This re-import **resets the document theme**: named styles revert to Google defaults, so brand fonts and heading colors are lost, and **anchored images are dropped** (a template logo stored as a positioned object disappears). In testing, after an HTML re-import the logo was gone and `HEADING_1` had lost both its font (Roboto) and color. Comments may also not survive. Do NOT use this path on a branded doc, a doc with a logo, or one whose custom named styles must be kept. Use "Pattern: clone a themed doc and rebuild its body" instead.

When to prefer this over `docs.documents.batchUpdate`:
- The doc is unbranded (plain default styling) and replacing the whole body is fine.
- You have the new content as HTML or Markdown and no theme to preserve.

When `docs.documents.batchUpdate` (Docs API) is better:
- The doc is themed/branded and the styling, logo, or named styles must survive (see the clone-and-rebuild pattern below).
- Inserting a paragraph at a specific location and the existing structure must be preserved.
- Applying small text-substitution edits across a doc (covered with `replaceAllText`).
- Modifying a doc with comments or suggestions you must preserve.

The Docs API `batchUpdate` is more involved (1-indexed character offsets, request-list pattern), but it is the only way to change content while keeping a theme.

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
  --json "$(cat /tmp/fill.json)"
```

`replaceAllText` works across all text in the doc, including inside table cells, footnotes, and headers. It does not touch images.

For **Slides** templates, the same JSON shape works against the Slides API:

```bash
gws slides presentations batchUpdate \
  --params "{\"presentationId\":\"${NEW_ID}\"}" \
  --json "$(cat /tmp/fill.json)"
```

Slides additionally supports `replaceAllShapesWithImage` (swap a placeholder image with a real one) and `replaceAllShapesWithSheetsChart` (embed a live Sheet chart).

For **Sheets** templates, copy the file, then use the `values.batchUpdate` pattern from the first section.

### When `replaceAllText` is not enough

If the template uses empty table cells instead of `{{placeholders}}` (common for HR / IDP / form templates), see `references/templates.md` for the "marker style" guidance and the structural-read fallback.

## Pattern: clone a themed doc and rebuild its body (preserve theme)

Use this when the user wants a NEW doc whose content differs from the template but which must keep a reference doc's branding: logo, named heading styles (font + color), page setup. This is the **only** reliable way to do that. HTML create and HTML body-replace both discard the theme (see the warnings above), and `replaceAllText` only works when the template already has `{{placeholders}}`. Here the template holds real prose, so you delete the old body and rebuild it through the Docs API, keeping the title block (which anchors the logo).

### Step 1: clone the template

```bash
NEW=$(gws drive files copy \
  --params '{"fileId":"<TEMPLATE_ID>","supportsAllDrives":true,"fields":"id,webViewLink"}' \
  --json '{"name":"My New Themed Doc"}')
NEW_ID=$(echo "$NEW" | jq -r .id)
```

The copy inherits the template's `namedStyles`, `positionedObjects` (the logo), and page setup. A copy of a shared-drive doc lands in the **same shared-drive folder** as the source unless you pass `"parents"`, so set `parents` (or move it afterward) to avoid leaving a draft in a customer folder.

### Step 2: inspect the structure, then delete the old body but keep the title block

```bash
# find where the real content starts (e.g. the first "Overview" heading) and the body end
gws docs documents get \
  --params '{"documentId":"<NEW_ID>","fields":"body(content(startIndex,endIndex,paragraph(elements(textRun(content)))))"}'
```

The Kong template anchors its logo as positioned objects on the **first paragraph (index 1)**, so deleting from the first content heading to `bodyEnd - 1` keeps the letterhead and logo. Delete with `deleteContentRange` (you cannot delete the final newline, hence `end - 1`):

```bash
gws docs documents batchUpdate --params '{"documentId":"<NEW_ID>"}' \
  --json '{"requests":[{"deleteContentRange":{"range":{"startIndex":89,"endIndex":<END-1>}}}]}'
```

### Step 3: rebuild content with named styles + real tables

Docs API indices are 1-indexed and shift with every insert, so a small script (drive `gws` from Python; the indexing is fiddly by hand) is the practical way. Key requests and the rules that make them work:

- **Paragraphs**: `insertText` (`text` ending in `\n`), then `updateParagraphStyle` setting `namedStyleType` to `HEADING_1/2/3` or `NORMAL_TEXT`. Because the doc is a clone, those named styles already carry the brand font/color, so headings render themed with no per-run styling.
- **Lists**: apply `createParagraphBullets` over the WHOLE run of consecutive list paragraphs in ONE request (a separate call per item restarts numbering). For nesting, set `indentStart` / `indentFirstLine` (about 36pt per level) before the bullets call. Presets: `BULLET_DISC_CIRCLE_SQUARE` (ul), `NUMBERED_DECIMAL_ALPHA_ROMAN` (ol).
- **Tables**: `insertTable` makes an empty table; then re-fetch the doc to read each cell's first-paragraph `startIndex`, and fill cells with `insertText` in **descending index order** (so earlier inserts do not invalidate later indices). Re-fetch once more to find the table `endIndex` and continue after it.
- **Bold lead-ins** (the Benefits style "Label: text"): `updateTextStyle` `bold` over `[start, start + len(label) + 1]`.

Sequence the build by inserting one run of paragraphs at a time, handling each table separately, and tracking a running cursor index. Verify at the end that the theme survived:

```bash
gws docs documents get --params '{"documentId":"<NEW_ID>","fields":"positionedObjects,namedStyles(styles(namedStyleType,textStyle(weightedFontFamily,foregroundColor)))"}'
# expect: positionedObjects still present (logo), HEADING_1 font=Roboto with its brand color
```

## Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| `gws is not authenticated` (from preflight) | No keyring/file credentials | Run the `gws-cli` skill's setup section |
| `Requested entity was not found` on a Drive file | File ID typo, or you do not have access | Verify the file is shared with the gws-authed user; for shared drives include `"supportsAllDrives": true` in `--params` |
| `Requested entity was not found` (404) on a Slides deck via Drive immediately after `presentations.create` | The deck was created via the Slides API and is invisible to the `drive.file` scope | Hand the user `https://docs.google.com/presentation/d/${PRES_ID}/edit`; widen scopes only if you need Drive metadata. Full trap notes: `references/slides-deep.md` |
| `Insufficient Permission` on `files.update` | `drive.file` scope only allows editing files the app created OR explicitly opened | Re-auth with broader Drive scope via `gws-cli` |
| HTML upload landed but tables look broken | Drive's HTML-to-Doc converter is finicky | Add explicit `border="1"` to `<table>` tags; avoid nested tables; use inline `style` attributes sparingly |
| Sheet write succeeded but cells show `#####` | Numbers got written as text | Set `valueInputOption: "USER_ENTERED"` to make Sheets parse them, or write JSON numbers (not strings) in the `values` array |
| `Invalid --json body: expected value at line 1 column 1` | `--json @file` is not supported in this `gws` build | Pass JSON inline, or `--json "$(cat file.json)"` |
| `--upload '...' resolves to '...' which is outside the current directory` | `gws` restricts `--upload` to the cwd | Copy the file into the cwd and use a relative path (`--upload ./file.html`) |
| Created or replaced doc has no branding, or its logo vanished | HTML import applies default named styles and drops positioned-object images | Clone the template and rebuild via the Docs API (see "clone a themed doc and rebuild its body") |
| `files.delete` on a shared-drive file returns 404 although the file is visible and editable | You have editor, not content-manager/organizer, on that shared drive (`canDelete: false`); Drive answers a delete you cannot perform with 404, not 403 | Check `capabilities(canDelete,canTrash)` first. If `canTrash`, trash it: `files.update` `--json '{"trashed":true}'`. For permanent removal, ask a shared-drive manager |

## When NOT to use this skill

- **Reading large amounts of data**: prefer the Drive MCP (`mcp__claude_ai_Google_Drive__*`) for reads; this skill is for writes.
- **Workspace admin tasks** (user/group/license management, Drive sharing audits): use `gam` instead.
- **Sheet-heavy data workflows with pandas**: prefer `gspread` + a service account.
- **Sending email, creating calendar events, listing Drive metadata, tasks, chat, etc.**: use the `gws-cli` skill (same underlying tool, broader scope).
