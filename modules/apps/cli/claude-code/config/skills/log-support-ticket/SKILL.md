---
name: log-support-ticket
description: >-
  Create Salesforce support cases via the sf CLI. Use when the user wants to log
  a support ticket, create a case in SFDC, file a support case, open a ticket for
  a customer, or says /log-support-ticket. Also trigger when the user says things
  like "log this", "open a case", "file a ticket", "create a case for [customer]",
  or provides a Slack thread URL with context about a customer issue that needs
  tracking. Handles account/contact lookup, priority and product type selection,
  AI-drafted subject/description from Slack threads or pasted context, file
  attachments, and clipboard output. Even if the user just pastes a Slack link
  and says "log this" -- that's enough to start.
---

# Log Support Ticket

Create a Salesforce Case using the `sf` CLI. Scripts in `scripts/` handle all SFDC
interaction deterministically. Your job is to orchestrate the workflow, extract context
from Slack threads and user input, draft the Subject and Description, and present
choices to the user.

## Scripts

All scripts are in `scripts/` relative to this skill file. Run them with `bash`.
Each script outputs structured JSON to stdout and errors to stderr.

| Script | Purpose | Args |
|--------|---------|------|
| `sfdc-query-picklist.sh` | Get picklist values for a Case field | `<field_api_name>` |
| `sfdc-search-accounts.sh` | Search accounts by name | `"<search_term>"` |
| `sfdc-query-contacts.sh` | Get contacts for an account | `<account_id>` |
| `sfdc-create-case.sh` | Create the Case record | env vars (see below) |
| `sfdc-attach-file.sh` | Attach a file to a Case | `<case_id> <file_path>` |

## Workflow

Follow these steps in order. Use `AskUserQuestion` for selections where noted.

### Step 0: Parse Input

Check the user's message for:
- A **Slack URL** (pattern: `https://*.slack.com/archives/*/p*`)
- **Free-text context** describing the issue (pasted text, file references, problem description)
- An **account name** if mentioned

Hold all extracted context for later steps.

### Step 1: Slack Thread Extraction (if URL provided)

If a Slack URL is present:

1. Parse the URL to extract `channel_id` and `message_ts`:
   - URL format: `https://domain.slack.com/archives/{channel_id}/p{timestamp}`
   - Convert timestamp: remove `p` prefix, insert `.` before the last 6 digits
   - Example: `p1776207364426769` -> `1776207364.426769`

2. Call `mcp__slack__slack_read_thread` with the extracted `channel_id` and `message_ts`.

3. From the thread, extract and hold:
   - **Issue context**: what's happening, what's expected, what's been tried
   - **Participants**: who reported, who's involved
   - **Technical details**: product versions, error messages, environment info
   - **Files/screenshots/logs**: note any files shared in the thread (for Step 9)
   - **Account/contact hints**: customer name, contact person mentioned

Focus on messages that describe the technical issue. Ignore social/acknowledgment messages.

### Step 2: Account Lookup

If the account name is already known from context or user input, search directly.
Otherwise, ask the user for the customer/account name.

Run: `bash scripts/sfdc-search-accounts.sh "<name>"`

Present results using `AskUserQuestion` with account names as options. If too many
results (>10), ask the user to refine the search term.

Store the selected `AccountId` and `AccountName`.

### Step 3: Contact Selection

Run: `bash scripts/sfdc-query-contacts.sh <account_id>`

Present contacts using `AskUserQuestion`. Show Name, Title, and Email in the option
descriptions so the user can identify the right person.

Store the selected `ContactId` and `ContactName`.

### Step 4: Priority

Run: `bash scripts/sfdc-query-picklist.sh Priority`

Present using `AskUserQuestion`. List "Normal (Recommended)" as the first option.

Store the selected `Priority`.

### Step 5: Product Type

Run: `bash scripts/sfdc-query-picklist.sh Product_Type__c`

Present using `AskUserQuestion`. If the product is already apparent from context
(e.g., Slack thread mentioned "Kong Mesh"), list that option first with "(Recommended)".

Store the selected `ProductType`.

### Step 6: Org ID (optional)

Ask: "Do you have a Konnect/Kong Org ID for this case? (optional)"

Use `AskUserQuestion` with options:
- "No Org ID / Skip"
- "Enter Org ID" (user provides via Other)

If the Org ID was already mentioned in the Slack thread or pasted context, pre-fill
it and ask for confirmation instead.

### Step 7: Draft Subject and Description

Read `references/description-template.md` for the Description format.

Using all collected context (user input, Slack thread, account, product, org ID), draft:

**Subject** -- concise, under 100 characters, captures the core issue.
- Format: `{Product} {Component}: {Brief Issue Summary}`
- Example: `Kong Mesh Zone CP Offline: KDS Connection Flapping on v2.13.0`

**Description** -- follow the template structure exactly:
- Opening line: "Opened on behalf of the customer."
- Org ID line (only if provided)
- ISSUE SUMMARY section
- ENVIRONMENT section (adapted to the product and available info)
- KEY DETAILS section

Present both the Subject and Description in fenced code blocks. Tell the user:
"Here's my draft. Edit anything you'd like to change, or confirm to proceed."

If the user provides edits, incorporate them and present the updated version.
Iterate until the user confirms.

### Step 8: Confirm and Create

Present a summary of all fields:

```
Priority:      {value}
Account:       {AccountName}
Contact:       {ContactName}
Product Type:  {value}
Subject:       {value}
Slack Thread:  {url or "none"}
Org ID:        {value or "none"}
```

On confirmation, create the case by running:

```bash
CASE_SUBJECT="..." \
CASE_DESCRIPTION="..." \
CASE_PRIORITY="..." \
CASE_ACCOUNT_ID="..." \
CASE_CONTACT_ID="..." \
CASE_PRODUCT_TYPE="..." \
CASE_SLACK_THREAD="..." \
bash scripts/sfdc-create-case.sh
```

Report the result: Case Number and URL.

### Step 9: File Attachments

Ask: "Would you like to attach any files (logs, screenshots)?"

If the Slack thread contained files, mention them: "The Slack thread included
[filenames]. Would you like to attach any local copies?"

For each file path provided, run:
```bash
bash scripts/sfdc-attach-file.sh <case_id> <file_path>
```

Report success/failure for each file. Continue until the user says they're done.

### Step 10: Post-Creation Output

1. Format the markdown link:
   ```
   [{Subject}]({case_url})
   ```

2. Copy to clipboard:
   ```bash
   printf '%s' '[{Subject}]({case_url})' | wl-copy
   ```

3. Tell the user the link has been copied to their clipboard.

4. Ask if they want to open the case in the browser:
   ```bash
   xdg-open "{case_url}"
   ```
