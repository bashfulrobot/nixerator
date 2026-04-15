---
name: log-github-issue
description: >-
  Create a well-structured GitHub issue on the current repository, written as
  a precise AI agent execution prompt. Use when the user wants to log a feature
  request, bug report, or improvement idea as a GitHub issue. Trigger on phrases
  like "log an issue", "create a github issue", "open an issue for", "write up an
  issue", "/log-github-issue", or whenever the user describes a feature or bug and
  wants it tracked. Even if the input is just a rough idea or a single sentence —
  that's enough to start. The skill gathers missing context through follow-up
  questions, then produces a complete, actionable issue body structured so that
  a subsequent AI agent can read it and implement the work without further
  clarification.
---

# Log GitHub Issue

Create a GitHub issue on the current repository. The output is a structured issue
body written as an AI agent execution prompt — precise enough that another agent
can pick it up and implement the work without ambiguity.

Use `gh` for all GitHub interaction. Ask follow-up questions to fill gaps before
writing the draft. Never add any AI attribution to the issue.

---

## Step 1: Detect Repository

```bash
gh repo view --json nameWithOwner,defaultBranchRef -q '{repo: .nameWithOwner, default_branch: .defaultBranchRef.name}'
```

If this fails, stop: **"Not in a GitHub repository. Run this from inside a repo directory."**

Hold `repo` and `default_branch` for use in the issue body.

---

## Step 2: Understand the Input

Read the user's initial message. Extract what they've told you:

- **What** — the feature, bug, or improvement being requested
- **Why** — the problem it solves or the motivation
- **Where** — relevant files, modules, or components (if mentioned)
- **Scope** — anything explicitly in or out of scope

---

## Step 3: Ask Follow-Up Questions

Identify what's missing. You need enough to write an unambiguous issue. Use
`AskUserQuestion` to fill the gaps — but only ask what isn't already clear.

**Common gaps and why they matter for an AI agent:**

| Missing | Why it blocks an agent |
|---------|----------------------|
| Acceptance criteria | Agent can't know when it's done |
| Relevant files or modules | Agent wastes time searching or touches the wrong code |
| Expected behavior vs. current behavior | Agent may implement the wrong thing |
| Constraints or things not to change | Agent may inadvertently break something |
| Related issues or PRs | Agent may duplicate or conflict with other work |
| Testing requirements | Agent may skip tests |

Ask no more than 3–4 targeted questions. If the user's input is already detailed,
skip or reduce questions.

**Examples of good follow-up questions:**

- "What should the end result look like — how will you know this is working correctly?"
- "Are there specific files or modules this should touch, or that it should avoid?"
- "Is there anything in scope you want to explicitly call out as out of scope?"
- "Are there related issues or PRs this connects to?"

---

## Step 4: Research the Codebase (if helpful)

If the issue touches a specific module or file that you can locate quickly, do a
brief lookup to give the agent precise pointers. This is worth doing when:

- The user mentioned a specific feature or component by name
- A file path or function name would make the requirements much clearer
- A quick `grep` or `glob` can confirm the right location

Keep this targeted — the goal is to add one or two precise anchors, not a full audit.

---

## Step 5: Draft the Issue

### Title

Concise, under 72 characters, describes the change clearly.

Format: `type: brief imperative summary`

Examples:
- `feat: add zoxide integration to fish shell config`
- `fix: statusline crashes when OAUTH token is unset`
- `refactor: extract per-host GPU config into separate module`

### Body

The body is written as an AI agent execution prompt. It should be self-contained:
a fresh agent with no prior context should be able to read it and implement the work.

Use this structure:

```
## Context

[2–4 sentences on why this change is needed and what problem it solves.
Written from the perspective of someone who knows the codebase well.
No first-person "I want" framing — state the problem and its impact.]

## Goal

[1–2 sentences stating the desired end state. Use imperative phrasing.
Example: "Add X so that Y." or "Fix Z so that W no longer occurs."]

## Acceptance Criteria

- [ ] [Specific, verifiable outcome]
- [ ] [Another verifiable outcome]
- [ ] [...]

## Scope

**In scope:**
- [What this issue covers]

**Out of scope:**
- [Explicitly what this issue does NOT cover]

## Technical Details

[Relevant file paths, function names, module names, patterns to follow,
constraints, related issues/PRs, or anything that helps an agent understand
the implementation space. Be specific. If there's a clear implementation
approach, describe it. If not, describe constraints and let the agent decide.]

## Testing

[How to verify the change works. Specific commands, expected output,
or test cases. If the project has a standard test approach (e.g., `just qr`
for a NixOS rebuild), reference it.]
```

**Tone:** Direct and technical. No hedging, no AI markers, no "this will be generated
by..." — write it as though an experienced engineer wrote it as a clear task spec.

Omit sections that genuinely don't apply (e.g., if there's no testing beyond
a build check, one line is fine). Never pad sections with filler.

---

## Step 6: Present and Iterate

Show the user:
1. The proposed **title** in a code block
2. The **body** in a fenced markdown block

Say: "Here's the draft. Edit anything you'd like to change, or confirm to proceed."

If the user provides edits, incorporate them and re-present. Iterate until confirmed.

---

## Step 7: Select Labels (optional)

```bash
gh label list --json name,description
```

If relevant labels exist (e.g., `bug`, `enhancement`, `feat`, `fix`), suggest 1–2
appropriate ones. Use `AskUserQuestion` with "Skip labels" as the first option.

---

## Step 8: Create the Issue

```bash
gh issue create \
  --title "<title>" \
  --body "<body>" \
  [--label "<label>"] \
  [--assignee "@me"]
```

Report the issue URL.

Ask: "Would you like to open this in the browser?" If yes:
```bash
xdg-open "<issue_url>"
```

---

## Rules

- **No AI attribution** — no mentions of Claude, AI, "generated", or any agent tool
  in the title, body, labels, or comments. The issue should read as if a human wrote it.
- **No vague requirements** — if a section can't be filled with specifics, ask.
  Vague acceptance criteria waste the implementing agent's time.
- **No padding** — omit sections that don't apply rather than filling them with
  placeholder text.
- **Imperative voice in acceptance criteria** — "File is created at X", not "should create".
