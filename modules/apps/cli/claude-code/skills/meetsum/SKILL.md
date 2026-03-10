---
name: meetsum
description: Summarize meeting transcripts into structured Slack-compatible markdown summaries with business casual tone.
argument-hint: "<path-to-meeting-directory>"
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - AskUserQuestion
  - Skill
  - mcp__claude_ai_Slack__slack_send_message_draft
  - mcp__claude_ai_Slack__slack_search_channels
---

# Meeting Transcript Summarizer

Summarize a meeting transcript into two Slack-compatible markdown files: a full summary and a Slack mini summary. Then rename the transcript, copy the full summary to clipboard, and draft the mini summary to Slack.

Bash is used for exactly two operations in this skill: `wl-copy` (clipboard) and `mv` (transcript rename). Do not use Bash for anything else.

## Inputs

1. Parse `$ARGUMENTS` for the meeting directory path. This argument is **required**. If missing, use `AskUserQuestion` to ask for it.
2. Inside that directory, Glob for `*.txt` files. There must be exactly one `.txt` file (the transcript). If zero or multiple are found, report the error and stop.
3. Optionally read `pov-input.md` from the same directory if it exists.

## Extract Metadata

- **Customer name**: Derive from the directory path. Look for a parent directory under `Customers/` (e.g., `/path/to/Customers/Acme/2026-03-10/` means customer is "Acme"). Convert to ALL CAPS for titles. If the customer name cannot be determined, use `AskUserQuestion` to ask.
- **Date**: Extract from the directory name if it matches `yyyy-mm-dd` format. Otherwise use today's date.
- **User name**: If the transcript references the user or you need first-person perspective, use `AskUserQuestion` to ask for their name.

## Processing Rules

### Tone and Style
- Business casual tone throughout
- Professional but conversational
- Write from the user's perspective (first person)
- Avoid overly formal or technical jargon unless necessary
- **NEVER use em dashes or en dashes anywhere in the output.** Use commas, semicolons, colons, parentheses, or separate sentences instead.
- Use straight quotes, never curly quotes

### Slack Markdown Rules (CRITICAL)
- `*text*` = bold
- `_text_` = italics
- `*_text_*` = bold italics
- **NEVER** use `**text**` anywhere in either document
- Use `-` for bullet points (not `*` or `+`)
- Use standard markdown for links

## Full Summary Structure

Generate the full summary with ALL of the following sections, in this order:

### 1. Document Title
Format: `*_yyyy-mm-dd CUSTOMER FULL CALL SUMMARY_*`
- ALL CAPS for entire title
- Bold italics Slack format
- Example: `*_2026-03-10 ACME FULL CALL SUMMARY_*`

### 2. Topic Sections
- Create separate sections for each distinct topic discussed in the transcript
- Title format: `_TOPIC NAME_` (ALL CAPS, italics only)
- Add a blank line after each topic title before the content
- Write in **paragraph format** (not bullet points)
- Do NOT indent paragraphs
- Extract ALL content from the transcript; maintain verbosity and include all relevant details
- Write from the user's first-person perspective
- If `pov-input.md` exists:
  - Parse bullet structure: top-level bullets are topics, nested bullets are details
  - Map topics from input file to corresponding transcript topics
  - Augment (don't replace) transcript content with input file details
  - **The transcript is the source of truth**; never add information not present in the transcript
  - Use input files to highlight what to look for and prioritize
  - Handle spelling mistakes, abbreviations, and inconsistent terminology

### 3. Activity Timeline (optional, only if dates/deadlines/milestones discussed)
- Title: `_ACTIVITY TIMELINE_` (italics only, all caps)
- Intro line: "To provide a clear view of upcoming milestones and deadlines discussed during the call:"
- Bullet format: `- *{Date}*: {Description}`
- Bold the date, list chronologically

### 4. People (optional, only if relevant people discussed)
- Title: `*PEOPLE*` (bold only, all caps)
- Bullet format: `- {Name} ({Role/Title}): {Responsibilities or context}`

### 5. Automation, Infrastructure & Tools (optional, only if discussed)
- Title: `*AUTOMATION, INFRASTRUCTURE & TOOLS*` (bold only, all caps)
- Bullet format: `- {Tool/System}: {Brief description or context}`

### 6. Risks (optional, only if discussed)
- Title: `*RISKS*` (bold only, all caps)
- Bullet format: `- {Risk description}` or `- {Risk}: {Mitigation if discussed}`

### 7. Highlights
- Title: `*HIGHLIGHTS*` (bold only)
- Bullet format with `-`
- Key insights, decisions, or notable moments

### 8. Action Items
- Title: `*ACTION ITEMS*` (bold only)
- Bullet format: `- {Assignee}: {Action item description}`
- Include deadlines when mentioned

### 9. Meeting Recording
- Title: `*MEETING RECORDING*` (bold only)
- Single bullet: `- [Clari Recording](PLACEHOLDER_URL)`

## Humanizer Pass

After generating the complete full summary, invoke `/humanizer` on the full summary text. This MUST happen before generating the Slack mini summary to ensure consistent content across both files. The humanizer removes AI writing patterns (inflated symbolism, promotional language, em dash overuse, AI vocabulary words, excessive conjunctive phrases).

## Slack Mini Summary

After the humanizer pass, generate the Slack mini summary by extracting from the (now humanized) full summary:

1. **Title**: Same format but WITHOUT "FULL": `*_yyyy-mm-dd CUSTOMER CALL SUMMARY_*`
2. **Highlights** section (copied from full summary)
3. **Action Items** section (copied from full summary)
4. **Risks** section (copied from full summary, only if it exists)
5. **Meeting Recording** section (copied from full summary)
6. Append at the end:

```
*FULL MEETING SUMMARY*

>>> :thread:
```

The Slack mini summary does NOT include: topic sections, activity timeline, people, or automation/tools.

## Output Files

Save both files to the meeting directory:

- Full summary: `yyyy-mm-dd-{CustomerName}-call-summary.md`
- Slack mini summary: `yyyy-mm-dd-{CustomerName}-call-summary-slack.md`

Where `{CustomerName}` matches the folder name under `Customers/` in the path (preserving original casing from the directory name).

## Transcript Rename

After saving the summary files, rename the original transcript file to `{DATE}-transcript.txt` (where `{DATE}` is the `yyyy-mm-dd` date extracted earlier). Skip this step if the filename already matches the `yyyy-mm-dd-transcript.txt` pattern. Use Bash `mv` for the rename.

## Clipboard and Slack Workflow

### Step 1: Copy full summary to clipboard

Use Bash to run `wl-copy` with the full summary content. If `wl-copy` fails (e.g., no Wayland session), tell the user the file path to copy manually and continue.

### Step 2: Draft mini summary to Slack

First, check if Slack MCP tools are available. If the `mcp__claude_ai_Slack__slack_search_channels` tool is not available or returns an error indicating Slack MCP is not active:
- Copy the mini summary to clipboard instead (replacing the full summary).
- Tell the user: "Slack MCP not active. Mini summary copied to clipboard."
- Skip the remaining Slack steps.

If Slack MCP is available:

1. Use `AskUserQuestion` to ask which Slack channel to post to. Suggest a likely name based on the customer (e.g., "Maybe #acme or #ext-acme?").
2. Search for the channel via `mcp__claude_ai_Slack__slack_search_channels`. If zero results, ask for the exact channel name or ID. If multiple results, present the list and ask the user to pick.
3. Draft the Slack mini summary via `mcp__claude_ai_Slack__slack_send_message_draft`. Do NOT include any Claude attribution in the message.
4. Handle errors gracefully:
   - **`draft_already_exists`**: Tell the user to send or delete the existing draft first, then re-run.
   - **`mcp_externally_shared_channel_restricted`**: Copy the mini summary to clipboard instead. Tell the user to paste manually.

### Step 3: Report results

Tell the user: "Mini summary drafted in #channel. Full summary is on your clipboard. Send the draft, then paste the full summary in the thread."

## Quality Checklist

Before saving, verify:
- [ ] Title follows exact format with correct date and customer name
- [ ] Full summary title says "FULL CALL SUMMARY" (no "CADENCE")
- [ ] Slack summary title says "CALL SUMMARY" (no "FULL", no "CADENCE")
- [ ] All section titles are properly formatted per the rules above
- [ ] Topic sections are in paragraph format with sufficient detail
- [ ] Optional sections included only when relevant content exists in transcript
- [ ] Action items include assignee names
- [ ] Meeting recording link uses PLACEHOLDER_URL
- [ ] No `**text**` markdown anywhere (use `*text*` for bold)
- [ ] No em dashes or en dashes anywhere
- [ ] No curly quotes
- [ ] Content maintains business casual tone, first-person perspective
- [ ] Humanizer was invoked on full summary before generating Slack mini summary
- [ ] Slack mini summary ends with the thread link block
- [ ] Both files written with correct filenames (no "cadence" in filename)
- [ ] Documents end with a blank line
