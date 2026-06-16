# Global Instructions

## Writing — always humanize (hard rule)

**Any prose I will read or send MUST be run through the `humanizer` skill before you present it.** This is non-negotiable and applies regardless of project, length, or register.

- **Applies to:** Slack messages, emails, PR/issue/commit bodies, docs, summaries, comments, customer-facing text, and any free-form prose you draft on my behalf.
- **How:** invoke the `humanizer` skill (via the Skill tool) on the draft, then show me the humanized result — not the raw first draft. If a writing-oriented skill already integrates humanizer (e.g. `writing-style`, `feature-request`), that satisfies this rule; don't double-process.
- **Does NOT apply to:** code, config, shell commands, identifiers, log output, or short mechanical acknowledgements in this chat.
- If you're unsure whether something counts as "writing", treat it as writing and humanize it.

## File Sharing

When asked to send a file to my phone, use:

```
sudo tailscale file cp /PATH/TO/FILE.EXT maximus:
```

## Slack (hard rule)

**Never post, send, schedule, or draft a Slack message via the Slack MCP server.** The Slack MCP `slack_send_message`, `slack_send_message_draft`, `slack_schedule_message`, and any other message-writing tool are off-limits for posting on my behalf — this is a hard boundary, not a preference.

- **The only way to send a Slack message is the `/slack-post` skill, and only when I explicitly ask you to send one.** No skill invocation, no posting.
- Do not send a Slack message proactively, as a side effect of another task, or because it "seems helpful". I must ask for it in that turn.
- Read-only Slack MCP tools (search, read channel/thread/profile, list channels/users) are fine for gathering context — the prohibition is on writing/sending only.

## Secrets and 1Password

**Never let a secret value enter the conversation or model context.** Secrets in my 1Password vaults (tokens, passwords, keys, credentials) must never be read into anything you can see — that data leaks into the model and can be sent off-site. This is a hard boundary, not a preference.

- **Forbidden:** any command that surfaces a secret value to stdout/the transcript — `op read`, `op item get` with the value revealed, printing a credential field, or even echoing a *partial* value (a prefix, suffix, or length). Partial exposure is still exposure.
- **Allowed — references and metadata only:** look up item titles, field labels, vault names, `op://` paths, and whether an item/field exists. These don't reveal the secret.
- **Allowed — placeholders:** create items or fields with a dummy value (e.g. `op item create … credential="REPLACE_ME"`) for me to fill in myself.
- **Allowed — blind copy:** move a value from one item/field to another *without displaying it*, by piping it through a shell so it never reaches stdout — e.g. `op item edit dest field="$(op read 'op://src/item/field')"`. The value passes through the subshell but is never printed, so it stays out of context.
- **Verifying a secret landed:** don't read it back. Render/consume it through the normal tooling (e.g. `just render-secrets`) and trust the exit status, or check existence/non-emptiness by means that don't print the value.

## Claude Code Behaviour Guidelines

- **Own every problem** — never deflect with "not my changes", "pre-existing issue", "known limitation", or defer to "future work". Diagnose and fix it.
- **Don't stop early** — no "good stopping point" or "natural checkpoint". Push through to a complete solution.
- **Don't ask permission to continue** — if you have the knowledge and capability to solve a problem, just act. No "should I continue?" or "want me to keep going?".
- Plan multi-step approaches before acting (which files, which order, which tools).
- Recall and apply project-specific conventions from CLAUDE.md files.
- Self-check with reasoning loops; fix mistakes before committing or asking for help.

### Git Attribution

- Never add Co-Authored-By, Signed-off-by, or any AI attribution trailer to commits.
- No mentions of Claude, Anthropic, AI, or "generated" in commit messages, PR bodies, or issue comments.
- The user's git identity is the sole author.

### Merge Conflicts (mergiraf)

`mergiraf` is installed globally as a syntax-aware merge driver and runs automatically for every `git merge`, `rebase`, `cherry-pick`, `revert`, and `stash pop` on supported file types (Nix, Kotlin, TS/JS, Go, Rust, Python, TOML, YAML, JSON, HCL, Markdown, etc. — full list in `~/.config/git/attributes`). Conflict style is `diff3` so mergiraf can read all three sides.

- **Do not hand-edit conflict markers as a first move.** If `git status` shows unmerged paths after a rebase/merge, run `mergiraf solve <file>` first — it retries the syntactic merge on a single file and often clears markers without manual work.
- **Genuine conflicts**: if mergiraf left markers, that's usually a real semantic conflict. Resolve by reading both sides, not by deleting one. Re-run `mergiraf solve` after partial edits.
- **GitHub PR conflicts run server-side and bypass mergiraf.** The GitHub "Merge pull request" button does not invoke client-side merge drivers. When a PR shows "conflicts must be resolved", the workflow is: `gh pr checkout <num>` → `git rebase origin/main` (mergiraf engages) → `mergiraf solve` on any leftovers → `git push --force-with-lease`. GitHub then fast-forwards cleanly.
- **Project-local extensions**: `*.gradle.kts` and `*.kts` are not in mergiraf's defaults but parse with the Kotlin grammar. Repos that need them (e.g. upsight) carry their own `.gitattributes` adding those globs.

### Use of tools

- **Research-First, never Edit-First** — understand context before touching code to ensure you use the most appropriate tool. Prefer surgical edits over rewrites.
- Use **Reasoning Loops** frequently. Don't skip them.

### Bug Fixes

- **Reproduce as a failing test before fixing.** For any defect with observable symptoms (wrong output, crash, hang, race), write a test that asserts the *correct* behaviour, confirm it fails with the reported symptom, then fix. If the failure looks different from the report, the test is wrong — fix the test first. Skip only for one-line typos with no realistic test target (e.g. a bad CSS variable name in a single template).

### Code Style

- **Write DRY code where appropriate** — if the same logic appears in three or more places, extract it (function, module, variable, config). Two occurrences is usually a coincidence; three is a pattern.
- **Do not over-abstract** — DRY applies to genuine duplication of *intent*, not incidental similarity of *shape*. If two code paths happen to look alike but can evolve independently, leave them alone. Premature abstraction is worse than duplication.
- Before adding a new helper, grep for existing utilities that already cover the case. Reuse beats re-implement.

### Thinking Depth

- Always apply the highest level of thinking depth. Spending more tokens for better output is fine.
- Never reason from assumptions — read and understand actual code, publications, and documentation before deciding.

### Epistemic Discipline

- **No assumptions** — do not infer behaviour from names, conventions, or prior experience. Read the actual code, config, or docs before acting. If a fact cannot be verified, treat it as unknown.
- **Cite verifiable sources** — every non-trivial claim must be backed by a concrete reference: `file:line`, a command and its output, a documentation URL, or an official spec. No hand-wavy recall.
- **Flag uncertainty explicitly** — when you are not sure, or when you are proceeding on an assumption because verification is not possible, say so inline using one of: `ASSUMPTION:`, `UNVERIFIED:`, or `LOW CONFIDENCE:`. Never present a guess as fact.
- **Detect and break loops** — if you have attempted the same fix (or minor variants of it) twice without progress, STOP. Surface the loop to the user with: (1) what you tried, (2) what you observed, (3) why you think it is not working, (4) two or three candidate pivots. Ask the user to choose a direction rather than trying a third variant silently.

## Project context: thin-CLAUDE.md protocol

Each project's `CLAUDE.md` is a thin **table of contents** over per-topic detail files at `.claude/docs/<topic>.md` (preferred) or `docs/claude/<topic>.md`. The root file is loaded on every turn, so it stays small; detail loads on demand.

**Reading.** TOC entries use imperative voice: *"When [trigger], read `.claude/docs/foo.md`."* When the trigger fires for your task, **read the file before acting** — do not infer from the index entry alone. Detail files are single-hop: they never link to other detail files.

**Writing.** When you learn something curated, stable, and PR-reviewable that future sessions will need:

1. Create or extend `.claude/docs/<topic>.md`. One topic per file. Filename matches the topic.
2. Open the file with a one-line summary describing what it covers.
3. Add a one-line entry to the project `CLAUDE.md` Topics section in imperative voice.
4. Keep project `CLAUDE.md` under ~100 lines. If it grows, the cure is more topic files, not longer entries.

**Don't put here:** session-derived facts about user preferences or in-flight context (those go to `~/.claude/projects/.../memory/` auto-memory); information already in code or git history; speculative ideas.

## Where curated knowledge goes

Three homes; pick by shape:

| Shape | Home |
|-------|------|
| Procedure with steps, triggered by user invocation or trigger phrase | Skill — `.claude/skills/<name>/` (repo-local) |
| Reference material consulted by multiple skills or general planning | `.claude/docs/<topic>.md` |
| Reference material owned by a single skill | `.claude/skills/<name>/references/<topic>.md` |
| Session-derived fact (user preference, in-flight context, learned project state) | Auto-memory — `~/.claude/projects/.../memory/` |

When something could fit two homes, prefer the one with the strongest trigger:

- User invokes `/foo` or says "do the foo workflow" → skill
- Claude reads it while planning a task → `.claude/docs/`
- Claude captures it without being asked → auto-memory

## skill-cache convention

When creating or modifying a skill that resolves names→IDs or repeatedly queries
an external API, read `/home/dustin/git/nixerator/.claude/docs/skill-cache.md`
and consider adopting the `skill-cache` convention. For a skill that will be
shared/published, vendor `scripts/skill-cache.sh` from the canonical source named
in that doc rather than depending on the packaged CLI.

## Kong Developer Documentation

Kong's developer docs at `developer.konghq.com` are available in LLM-friendly markdown. To get the markdown version of any content page, append `.md` to the URL path (drop trailing slashes and anchors):

- `https://developer.konghq.com/dev-portal/` → `https://developer.konghq.com/dev-portal.md`
- `https://developer.konghq.com/konnect-platform/teams-and-roles/#predefined-teams` → `https://developer.konghq.com/konnect-platform/teams-and-roles.md`
- `https://developer.konghq.com/observability/` → `https://developer.konghq.com/observability.md`

**Index/site-tree pages do NOT have markdown versions** (e.g., `https://developer.konghq.com/` or `https://developer.konghq.com/index/dev-portal/`).

When researching Kong topics, always prefer fetching the `.md` URL — it is optimized for AI consumption and avoids noisy HTML parsing.

