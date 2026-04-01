# Meeting Prep Skill Design

## Problem

As a Technical CSM, preparing for customer meetings requires reading through a folder of documents (transcripts, summaries, notes, PDFs, CSVs) and synthesizing them into an actionable meeting prep. This process is repeated for every meeting. The current approach involves writing a prompt ad hoc each time, which produces inconsistent quality and wastes time.

## Solution

A Claude Code skill (`meeting-prep`) that reads all documents in the current working directory, synthesizes them, and writes a structured meeting prep file. Follows the same deployment and invocation pattern as the existing `csat` skill.

## Invocation

```
/meeting-prep
```

No arguments required -- reads from the current directory. The user `cd`s into the account folder before invoking. Optionally accepts a path: `/meeting-prep ./path/to/folder`.

## Input

Reads all files in the target directory:
- `.md`, `.txt` -- read directly
- `.pdf` -- read via the Read tool (PDF support)
- `.csv` -- read directly as text
- Any other text-readable formats present

Files are processed with newest content prioritized (by filename date patterns or modification time) to weight recent context.

## Output

Written to `YYYY-MM-DD-meeting-prep.md` in the target directory. All text runs through the `humanizer` skill before writing.

### Output structure

```markdown
# Meeting Prep -- [Customer Name], [Date]

## Account Summary

Narrative form. Who they are, what their setup looks like, key contacts and
their roles, current state of the relationship. Written from the CSM's
first-person perspective. Concise but complete enough that someone picking
up this account cold could get oriented.

## Timeline

Chronological summary of past meetings and significant events. What happened,
what was decided, what shifted. Each entry includes the date and the key
takeaways. Gives continuity across calls so nothing falls through the cracks.

## Open Action Items

Carried forward from prior meetings. Each item includes:
- Owner (customer contact or CSM)
- What's expected
- Deadline if known
- Current status if inferable from the documents

## Agenda

Numbered items, prioritized by value-impact and urgency. Each item includes:
- What to discuss and why it matters right now
- Specific questions to ask, grounded in the document context
- Enough background that the CSM doesn't need to re-read source material
  during the call

Items should drive outcomes, not just check status. Frame topics around value,
adoption, risk, and expansion -- not "any updates on X?"

## Preparation Notes

First-person strategic thinking. This section is the difference between a
status check and a value-driving conversation. Includes:
- What the CSM wants to accomplish in this meeting
- What to push on and what to leave alone
- Blind spots or relationship dynamics to be aware of
- Tactical notes: how to frame difficult topics, when to listen vs. steer
- Signals to watch for during the conversation
```

### Writing rules

- First-person perspective throughout (written as the CSM's own prep, not a report)
- Narrative where narrative works, bullets where bullets work -- don't force either
- Concise but not telegraphic. Every sentence should carry information.
- Use straight quotes, no em dashes, no emojis
- If the documents don't support a claim, say so rather than fabricating
- Run all output through `humanizer` before writing the file
- Keep the total output scannable -- a CSM should be able to review it in 5-10 minutes before a call

## Skill metadata

```yaml
name: meeting-prep
description: Generate a meeting preparation brief from account documents in the current directory.
allowed-tools: ["Bash", "Read", "Grep", "Glob", "Skill", "Write"]
```

Note: includes `Write` (unlike `csat`) because this skill writes the output file directly.

## File structure

```
modules/apps/cli/claude-code/skills/meeting-prep/
  SKILL.md        # Skill definition
```

Also added to the config mirror:
```
modules/apps/cli/claude-code/config/skills/meeting-prep/
  SKILL.md        # Deployed copy
```

## Deployment

Deployed via the existing Nix module at `modules/apps/cli/claude-code/default.nix`, which copies skills from `config/skills/` to `~/.claude/skills/` on activation. No changes needed to the deployment mechanism -- adding the directory is sufficient.

## Verification

1. `cd` into a test account folder with mixed document types
2. Run `/meeting-prep` in Claude Code
3. Confirm output file is created with correct date-based name
4. Confirm all five sections are present and populated
5. Confirm output reads naturally (humanizer pass working)
6. Confirm no fabricated details -- all claims traceable to source documents
7. Run `nix fmt` and `statix` on any Nix changes
