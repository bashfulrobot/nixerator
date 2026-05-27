# Per-service quickstart recipes for `gws`

One-liner starters per service. For each entry, the goal is "here is the first call you would make to do X." Pair each recipe with `gws schema <method> --resolve-refs` when you need the full request body.

All commands assume `gws auth status` reports `"storage": "keyring"` or `"file"`. If not, see the `gws-cli` SKILL.md setup section.

## drive

```bash
# Find a file by name across My Drive and shared drives
gws drive files list \
  --params '{"q":"name contains '\''QBR'\''","supportsAllDrives":true,"includeItemsFromAllDrives":true,"fields":"files(id,name,mimeType,modifiedTime,parents,webViewLink)"}'

# Get a file's metadata
gws drive files get --params '{"fileId":"abc123","fields":"id,name,mimeType,parents,owners,sharedWithMeTime,webViewLink"}'

# Download a binary file
gws drive files get --params '{"fileId":"abc123","alt":"media"}' --output /tmp/out.bin

# Move a file to a new folder (single-parent semantics)
gws drive files update --params '{"fileId":"abc123","addParents":"NEW_FOLDER_ID","removeParents":"OLD_FOLDER_ID","fields":"id,parents"}'

# Create a folder
gws drive files create --json '{"name":"My Folder","mimeType":"application/vnd.google-apps.folder","parents":["PARENT_FOLDER_ID"]}'

# Share a file with a user (no notification, reader)
gws drive permissions create \
  --params '{"fileId":"abc123","sendNotificationEmail":false,"supportsAllDrives":true}' \
  --json '{"role":"reader","type":"user","emailAddress":"someone@example.com"}'
```

## gmail

```bash
# List the 10 most recent messages in inbox
gws gmail users messages list --params '{"userId":"me","maxResults":10,"labelIds":["INBOX"]}'

# Get one message's metadata + snippet
gws gmail users messages get --params '{"userId":"me","id":"MSG_ID","format":"metadata"}'

# Get the full raw RFC 5322 (base64url-encoded in .raw)
gws gmail users messages get --params '{"userId":"me","id":"MSG_ID","format":"raw"}'

# Mark a message as read (remove UNREAD label)
gws gmail users messages modify \
  --params '{"userId":"me","id":"MSG_ID"}' \
  --json '{"removeLabelIds":["UNREAD"]}'

# Apply a label
gws gmail users messages modify \
  --params '{"userId":"me","id":"MSG_ID"}' \
  --json '{"addLabelIds":["Label_42"]}'

# Create a draft (raw is the same base64url-encoded RFC 5322 as send)
gws gmail users drafts create \
  --params '{"userId":"me"}' \
  --json "{\"message\":{\"raw\":\"${RAW}\"}}"

# Search via the same query syntax as the Gmail UI
gws gmail users messages list --params '{"userId":"me","q":"from:noreply@example.com newer_than:7d","maxResults":50}'
```

## calendar

```bash
# List calendars the user has access to
gws calendar calendarList list --format table

# List events on a calendar for a date range
gws calendar events list \
  --params '{"calendarId":"primary","singleEvents":true,"orderBy":"startTime","timeMin":"2026-05-27T00:00:00-07:00","timeMax":"2026-06-03T00:00:00-07:00"}'

# Quick-add via natural language (uses Google's parser)
gws calendar events quickAdd --params '{"calendarId":"primary","text":"Dentist tomorrow 3pm for 1 hour"}'

# Update an event (patch semantics, only send fields you change)
gws calendar events patch \
  --params '{"calendarId":"primary","eventId":"EVENT_ID"}' \
  --json '{"summary":"Updated title"}'

# Delete an event
gws calendar events delete --params '{"calendarId":"primary","eventId":"EVENT_ID"}'

# Add an attendee to an existing event
gws calendar events patch \
  --params '{"calendarId":"primary","eventId":"EVENT_ID","sendUpdates":"all"}' \
  --json '{"attendees":[{"email":"existing@example.com"},{"email":"new@example.com"}]}'
```

Note: `attendees` is full-replace, not additive. Fetch the existing list first if you do not want to drop people.

## tasks

```bash
# List the user's task lists
gws tasks tasklists list

# List tasks on a list, including completed ones
gws tasks tasks list --params '{"tasklist":"TASKLIST_ID","showCompleted":true,"maxResults":100}'

# Mark a task complete
gws tasks tasks patch \
  --params '{"tasklist":"TASKLIST_ID","task":"TASK_ID"}' \
  --json '{"status":"completed"}'

# Reschedule a task
gws tasks tasks patch \
  --params '{"tasklist":"TASKLIST_ID","task":"TASK_ID"}' \
  --json '{"due":"2026-06-15T00:00:00Z"}'
```

## chat

```bash
# List Chat spaces the user is a member of
gws chat spaces list --format table

# Send a plain message to a space
gws chat spaces messages create \
  --params '{"parent":"spaces/AAAA..."}' \
  --json '{"text":"Quick update: deploy starting now."}'

# Send a card v2 message (rich UI)
gws chat spaces messages create \
  --params '{"parent":"spaces/AAAA..."}' \
  --json '{"cardsV2":[{"cardId":"c1","card":{"header":{"title":"Deploy","subtitle":"v1.2.3"},"sections":[{"widgets":[{"textParagraph":{"text":"Rolled out cleanly."}}]}]}}]}'

# Read messages in a space
gws chat spaces messages list --params '{"parent":"spaces/AAAA...","pageSize":20}'
```

## people

```bash
# Look up a contact by email
gws people people searchContacts --params '{"query":"someone@example.com","readMask":"names,emailAddresses,phoneNumbers"}'

# Get the authenticated user's profile
gws people people get --params '{"resourceName":"people/me","personFields":"names,emailAddresses,photos"}'

# List your contacts
gws people people connections list --params '{"resourceName":"people/me","personFields":"names,emailAddresses","pageSize":50}'
```

## forms

```bash
# Get a form's metadata + question list
gws forms forms get --params '{"formId":"FORM_ID"}'

# List responses
gws forms forms responses list --params '{"formId":"FORM_ID"}'
```

## keep

```bash
# List notes
gws keep notes list

# Get one note
gws keep notes get --params '{"name":"notes/NOTE_ID"}'
```

## classroom

```bash
# List courses the user owns or teaches
gws classroom courses list --params '{"teacherId":"me","courseStates":["ACTIVE"]}'

# List students in a course
gws classroom courses students list --params '{"courseId":"COURSE_ID","pageSize":100}'

# Post an announcement
gws classroom courses announcements create \
  --params '{"courseId":"COURSE_ID"}' \
  --json '{"text":"Reminder: assignment due Friday.","state":"PUBLISHED"}'
```

## meet

```bash
# Create a Meet conference (returns a join URI)
gws meet spaces create --json '{}'

# Get conference records for analytics
gws meet conferenceRecords list --params '{"pageSize":10}'
```

## admin-reports (alias: `reports`)

Requires Workspace admin scopes; will 403 for non-admin users.

```bash
# Login audit events for the last 24h
gws admin-reports activities list --params '{"userKey":"all","applicationName":"login","maxResults":50}'

# Drive sharing changes
gws admin-reports activities list --params '{"userKey":"all","applicationName":"drive","eventName":"change_acl_editors"}'
```

## script (Apps Script management)

```bash
# List your Apps Script projects
gws script projects list

# Run a deployed function (requires explicit execution API setup on the script)
gws script scripts run \
  --params '{"scriptId":"SCRIPT_ID"}' \
  --json '{"function":"myFunction","parameters":["arg1","arg2"]}'
```

## Tips when adding a new recipe

- Always run `gws schema <service.resource.method> --resolve-refs` first to confirm field names and required vs. optional.
- Use `--dry-run` to validate `--params` / `--json` shapes locally before sending.
- Wrap raw JSON in single quotes when there is no shell interpolation; switch to double quotes (and escape inner `"`) when you need to interpolate a variable.
- For long, structured request bodies, write to `/tmp/body.json` and pass `--json @/tmp/body.json` instead of inlining.
- Pipe through `jq` to keep output readable; for ad-hoc spotting, `--format table` is friendlier than `json`.
