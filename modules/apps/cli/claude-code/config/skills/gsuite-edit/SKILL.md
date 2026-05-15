---
name: gsuite-edit
description: Edit Google Sheets cells and create, copy, or replace Google Docs and Slides from the command line using gcloud Application Default Credentials and the Drive / Sheets / Docs / Slides REST APIs. Use this skill whenever the user wants to write data into a Google Sheet (e.g. "fill in column X", "batchUpdate these cells", "write self-assessment scores", "update notes/evidence column"), create a Google Doc programmatically (e.g. "make a Google Doc from this markdown / HTML"), replace the body of an existing Google Doc (e.g. "rewrite the IDP doc", "swap out the deck content"), or work from a Workspace template (e.g. "copy this template", "fill in the template placeholders", "clone the IDP template and pre-populate it", "make a copy of the QBR deck template"). Also triggers when the user mentions Google Sheets API, Docs API, Slides API, Drive API, batchUpdate, files.copy, replaceAllText, gcloud ADC, gspread, or asks how to edit Workspace files from a script. Prefer this skill over reaching for a Python SDK when the user just needs a few cell writes, a single doc replacement, or a template-copy-and-fill flow -- curl + ADC is faster and has no dependencies.
---

# gsuite-edit — edit Google Sheets and Docs from the CLI

This skill captures a battle-tested approach for editing Google Workspace files (Sheets, Docs) programmatically using `gcloud` Application Default Credentials and the Google REST APIs. It is fast, dependency-free (just `curl` + `gcloud`), and works for the common "update some cells" or "replace a doc body" tasks without needing a Python SDK or a service account.

## When this skill applies

Use whenever the user wants to write to a Google Sheet or Doc they own (or that they have edit access to) from the command line. Common signals:

- "Write these scores into the sheet"
- "Update column X for rows 12-28"
- "Create a Google Doc with this content"
- "Replace the body of this Doc"
- "How do I batchUpdate a Sheet from a shell script?"

**Do not** use this skill if:
- The user has a service account JSON and is comfortable with Python (just use `gspread` or `google-api-python-client`).
- The task is admin-level Workspace administration (use `gam` instead — see Alternatives below).
- The user needs to read large amounts of data — read via the Drive MCP if available; this skill is for writes.

## One-time setup: gcloud ADC with the right scopes

The default `gcloud auth login` does **not** include the Sheets / Drive scopes. Without them, every API call returns 403 `ACCESS_TOKEN_SCOPE_INSUFFICIENT`. Re-auth Application Default Credentials with the explicit scopes:

```bash
gcloud auth application-default login \
  --scopes=openid,email,\
https://www.googleapis.com/auth/cloud-platform,\
https://www.googleapis.com/auth/spreadsheets,\
https://www.googleapis.com/auth/drive.file
```

- `spreadsheets` — read/write any sheet the user has access to
- `drive.file` — create new Drive files and modify files the user authored via this app
- `cloud-platform` — needed for the quota-project mechanism (see next section)

You can re-run this any time the user adds new scopes later. The `--update-adc` flag on `gcloud auth login` also writes ADC, but using `application-default login` is the cleaner path.

To verify the scopes landed:

```bash
TOKEN=$(gcloud auth application-default print-access-token)
curl -sS "https://oauth2.googleapis.com/tokeninfo?access_token=$TOKEN" | grep scope
```

You should see `spreadsheets` and `drive.file` in the output.

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

The project doesn't need to be related to the sheet/doc owner — it just needs to be a project the user has access to. Sheets / Docs / Drive APIs must be enabled in that project (they are by default for any GCP project that was created via the console).

## Pattern: write cells in a Sheet (values.batchUpdate)

Use `spreadsheets.values:batchUpdate` to write one or more ranges in a single call. This is by far the fastest way to update a Sheet — one API hit can write to many ranges across multiple tabs.

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
- `mimeType: application/vnd.google-apps.document` tells Drive to convert the HTML to a Doc on import. Drive supports basic HTML — headings, paragraphs, lists, tables with `border` attributes, bold/italic/code, links.
- For a Sheet, use `application/vnd.google-apps.spreadsheet` and an HTML table or CSV body. For Slides, use `application/vnd.google-apps.presentation` (but conversion fidelity is lower; consider creating an empty deck and using the Slides API instead).
- `supportsAllDrives=true` lets you target shared drives.
- The new file goes to the user's My Drive root by default. To put it in a specific folder, add `"parents": ["<folder_id>"]` to the metadata JSON.

## Background: what "New from template" actually is

When a Workspace user opens Docs/Sheets/Slides and clicks **File → New → From a template gallery**, they see two sections:

1. **General templates** — Google-provided defaults (Resume, Project Tracker, Meeting Notes, etc.). These are real Drive files owned by Google with stable, publicly-known file IDs.
2. **Your org's templates** — admin-published templates specific to the Workspace tenant. The admin configures these in Admin Console → Apps → Google Workspace → Drive and Docs → Templates. Behind the scenes, this points at a Drive folder. Anything in that folder shows up in the gallery.

**There is no dedicated `templateGallery` REST endpoint.** The Drive UI is rendering a normal Drive folder. Programmatic access is just `files.list` against the right folder, plus `files.copy` to clone an entry.

### What this means for the skill

- If the user knows the file ID of a template (because they opened it once or got a link), `files.copy` works immediately — no special handling needed.
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
  "kong_dark_slide_theme_2026": "1BlmOgUbYcw7eBgNhyi3N5masysljt7yvOcU9fxmGPtg"
}
```

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

If the template uses `{{placeholder}}` syntax (or any other marker — `<<name>>`, `[CSM_NAME]`, etc.), use `documents.batchUpdate` with `replaceAllText` requests:

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

- `replaceAllText` — substitute marker strings (most common for templates).
- `insertText` — insert text at a specific 1-indexed character offset. Use only when you already know the offset; getting it usually requires reading the doc structure first via `documents.get`.
- `insertTableRow` / `insertTableColumn` — add rows/columns to existing tables. Useful when the template has a fixed-row table you need to extend (e.g. an Action Plan table with 5 rows but you have 7 items).
- `deleteContentRange` — remove a range. Useful for stripping placeholder boilerplate.
- `updateTextStyle` / `updateParagraphStyle` — change formatting on a range. Rare for templates since the template already has the styles you want.

For Slides templates (PPTX-style), the Slides API has the same `replaceAllText` plus `replaceAllShapesWithImage` (swap a placeholder image with a real one) and `replaceAllShapesWithSheetsChart` (embed a live Sheet chart). Endpoint is `https://slides.googleapis.com/v1/presentations/${PRES_ID}:batchUpdate`.

For Sheets templates, just copy the file and then use the `values:batchUpdate` pattern from the Sheets section above to fill in cells.

### When `replaceAllText` is not enough

If the template uses **empty table cells** instead of `{{placeholders}}` (which is common for Workspace IDP / form templates), `replaceAllText` won't help — there's no marker to find. Two options:

1. **Read the structure first.** Call `documents.get` to retrieve the doc as a JSON tree, find the table cell offsets you need, then use `insertText` with the right `index` value. This is fiddly but works.
2. **Accept that the user fills it in by hand.** Copy the template, hand them the URL, and let them paste in the prepared content. This is often the better trade-off for one-off filings like an annual self-assessment.

The decision is: how often will this template be filled? Once a year → manual paste. Every week with consistent placeholder names → invest in `replaceAllText` (or get the template author to add `{{placeholders}}`).

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
  -d '{"name": "FY27 IDP — Dustin Krysak"}' \
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

The cleanest way to swap out a Doc's entire body is a Drive media PATCH with new HTML. Drive re-imports the HTML and replaces the content. The Doc's `id`, `webViewLink`, sharing settings, and comments all persist — only the body changes.

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

The Docs API batchUpdate is much more involved — it uses 1-indexed character offsets and a request-list pattern. Reach for it only when surgical edits matter. For "rewrite the whole thing," the media PATCH above is faster and cleaner.

## Common errors and fixes

| Error | Cause | Fix |
|---|---|---|
| `ACCESS_TOKEN_SCOPE_INSUFFICIENT` | gcloud token lacks sheets/drive scope | Re-run `gcloud auth application-default login --scopes=...` (see Setup) |
| `Method doesn't allow unregistered callers` / `quota project not set` | Missing `X-Goog-User-Project` header on a user-credential call | Add `-H "X-Goog-User-Project: $(gcloud config get-value project)"` |
| `Requested entity was not found` on a Drive file | File ID typo or you don't have access | Verify the file is shared with the gcloud-authed user; for shared drives add `supportsAllDrives=true` |
| `Insufficient Permission` on `files.update` | `drive.file` scope only allows editing files the app created OR explicitly opened. Pre-existing Docs not authored via your token may need a broader scope | Re-auth with `https://www.googleapis.com/auth/drive` (full Drive access) if you need to edit arbitrary docs |
| HTML upload landed but tables look broken | Drive's HTML→Doc converter is finicky | Add explicit `border="1"` to `<table>` tags; avoid nested tables; avoid CSS — use inline `style` attributes sparingly |
| Sheet write succeeded but cells show `#####` | Numbers got written as text | Set `valueInputOption: "USER_ENTERED"` to make Sheets parse them, or write JSON numbers (not strings) in the `values` array |

## Alternatives (when not to use this skill)

| Tool | What it's good at | When to choose it |
|---|---|---|
| **`gam` (Google Apps Manager)** | Workspace admin: user/group/license management, Drive sharing audits, bulk operations on Drive files | When you're administering a Workspace tenant, not just editing one file |
| **`gspread` (Python)** | Sheet-heavy workflows with multiple reads/writes, pandas integration | When you'd rather write Python than bash, especially with data analysis afterward |
| **`google-api-python-client`** | Full coverage of every Google API, programmatic flexibility | When you need APIs this skill doesn't cover (Calendar, Gmail, BigQuery, etc.) |
| **Drive MCP (`mcp__claude_ai_Google_Drive__*`)** | Reading file metadata, file content, listing recent files | When you only need to read, not write. The MCP doesn't have edit tools. |
| **Google Apps Script** | Logic that runs inside Google's environment with no auth overhead | When the task is event-driven (form submission, on-edit) or runs on a schedule via Workspace |
| **`clasp`** | Managing Google Apps Script projects from CLI | Companion to Apps Script — push/pull script files |

For 90% of "I just need to write some cells / create a doc / replace a doc body" tasks from a shell, the curl + ADC pattern in this skill is the simplest path.

## Quick reference — minimal working script

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

# usage:
# gsuite_curl "https://sheets.googleapis.com/v4/spreadsheets/$SHEET_ID?fields=sheets.properties"
# gsuite_curl -X POST -H "Content-Type: application/json" -d @body.json "https://sheets.googleapis.com/v4/spreadsheets/$SHEET_ID/values:batchUpdate"
```

Drop into `~/.bashrc` or a project script and the API calls become one-liners.
