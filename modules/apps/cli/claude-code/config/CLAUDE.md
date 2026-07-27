# Global Instructions

## Writing — always humanize (hard rule)

**Any prose I will read or send MUST be run through the `humanizer` skill before you present it.** This is non-negotiable and applies regardless of project, length, or register.

- **Applies to:** Slack messages, emails, PR/issue/commit bodies, docs, summaries, comments, customer-facing text, and any free-form prose you draft on my behalf.
- **How:** invoke the `humanizer` skill (via the Skill tool) on the draft, then show the humanized result, not the raw first draft. A writing skill that already integrates humanizer (`text-polish`, `writing-style`, `feature-request`) satisfies this — don't double-process. `text-polish` runs humanizer then a concision pass, so "polished" already means "humanized"; never re-invoke humanizer on top.
- **Does NOT apply to:** code, config, shell commands, identifiers, log output, or short mechanical acknowledgements in this chat.
- **Does NOT apply to the `text-polish` filter (SUPER+SHIFT+R).** That keybind runs `claude -p` as a silent, non-interactive text-rewriting filter whose entire output is pasted straight into whatever field has focus. When you are that filter (the request tells you to output only the rewrite between markers), do NOT invoke the humanizer skill, do NOT deliberate about whether to, and do NOT emit any process narration. Rewrite in place, per the request's own rules, and output only the result. Any reasoning you emit gets pasted into a live document, so there is none.
- If you're unsure whether something counts as "writing", treat it as writing and humanize it.

## Slack (hard rule)

**Never post, send, schedule, or draft a Slack message via the Slack MCP server** — `slack_send_message`, `slack_send_message_draft`, `slack_schedule_message`, and any other message-writing tool are off-limits for posting on my behalf. Hard boundary, not a preference.

- **The only way to send a Slack message is the `/slack-post` skill, and only when I explicitly ask that turn.** No proactive sends, no sending "because it seems helpful," no side-effect posting.
- Read-only Slack MCP tools (search, read channel/thread/profile, list channels/users) are fine for gathering context — the prohibition is on writing/sending only.

## Secrets and 1Password (hard rule)

**Never let a secret value enter the conversation or model context.** Secrets in my 1Password vaults (tokens, passwords, keys, credentials) must never be read into anything you can see — that data leaks into the model and can be sent off-site. This is a hard boundary, not a preference.

- **Forbidden:** any command that surfaces a secret value to stdout/the transcript — `op read`, `op item get` with the value revealed, printing a credential field, or even echoing a *partial* value (a prefix, suffix, or length). Partial exposure is still exposure.

Allowed mechanics (references, placeholders, blind copy, verifying a landed secret) are in the Trigger-scoped rules below.

## Claude Code Behaviour Guidelines

- **Own every problem.** Never deflect with "not my changes," "pre-existing issue," or "future work." Diagnose and fix it.
- **Don't stop early or ask permission to continue.** No "good stopping point," no "should I continue?" If you have the knowledge and capability, act.
- Plan multi-step approaches before acting; recall project conventions from CLAUDE.md files; self-check with reasoning loops before committing or asking for help.

### Git Attribution

- Never add Co-Authored-By, Signed-off-by, or any AI attribution trailer to commits.
- No mentions of Claude, Anthropic, AI, or "generated" in commit messages, PR bodies, or issue comments.
- The user's git identity is the sole author.

### Merge and push-to-main authorization

- Merging a PR into `main`, or pushing straight to `main`, is authorized only when I explicitly ask for that specific action in the same turn — "merge PR #42," "push this to main," said right now, not inferred from context or a standing preference. This gate is identical in every session type: the test is "did I ask for this, right now," not "is this a background job." A background session given an explicit in-turn ask should just do it, not hand back a command for me to run.
- Without that ask, merging or pushing to main stays off-limits no matter how obviously correct it looks — surface it as an option and let me decide.
- Force-pushes and other destructive git operations (`git reset --hard`, discarding branches) are a separate, narrower case: always need explicit confirmation, in every session, independent of the rule above.

### Approach

- **Research-first, never edit-first, depth over speed.** Understand context before touching code; prefer surgical edits over rewrites; use reasoning loops frequently. Apply the highest thinking depth — token cost for better output is fine. Never reason from assumptions; read the actual code, docs, or publication before deciding.

### Epistemic Discipline

- **No assumptions.** Read the actual code, config, or docs before acting; don't infer from names, conventions, or prior experience. An unverifiable fact is unknown.
- **Cite sources.** Every non-trivial claim needs a concrete reference — `file:line`, a command's output, a doc URL, or a spec. No hand-wavy recall.
- **Flag uncertainty** inline with `ASSUMPTION:`, `UNVERIFIED:`, or `LOW CONFIDENCE:` rather than presenting a guess as fact.
- **Break loops.** Two failed attempts at the same fix (or minor variants) means stop: tell me what you tried, what you observed, why it's not working, and 2-3 candidate pivots. Don't try a third variant silently.

## Trigger-scoped rules (detail lives in skills or docs)

These rules still bind; only the detail moved. Invoke the named skill or read the
named doc before acting — don't work from the one-liner alone.

- Before fixing any defect with an observable symptom, reproduce it as a failing test first — invoke `bug-fix-workflow`.
- Before extracting a helper or abstraction, apply the three-occurrence DRY threshold — invoke `code-style`.
- When `git status` shows unmerged paths or a PR reports conflicts, run `mergiraf solve` before hand-editing markers — invoke `merge-conflicts`.
- When I say "git cleanup", "clean up the git stuff", or "wrap this branch up", that is standing authorization to commit, push, PR, squash-merge to `main`, and remove the worktree — invoke `git-cleanup`.
- When Bash output looks filtered or truncated, `rtk` wrapped it; `RTK_DISABLED=1 <cmd>` bypasses it once — invoke `rtk-output-compression`.
- When I ask you to copy something to my clipboard or send a file to my phone, never hardcode `wayland-1` and never guess the transfer command — invoke `send-to-dustin`.
- Before fetching anything from `developer.konghq.com`, append `.md` to the URL path — invoke `kong-docs-lookup`.
- When writing a project `CLAUDE.md`, a `.claude/docs/` topic file, or deciding where durable knowledge belongs, follow the thin-CLAUDE.md protocol — invoke `curated-knowledge`.
- When moving 1Password values (references, placeholders, blind copy, verification), read `/home/dustin/git/nixerator/extras/docs/secrets.md`.
- When a skill resolves names to IDs or repeatedly queries an external API, read `/home/dustin/git/nixerator/.claude/docs/skill-cache.md` for the `skill-cache` convention.

# Compact instructions

- **Preserve:** decisions and their reasoning; constraints and rules stated in conversation; in-flight state (done, half-done, remaining); file paths, identifiers, branch/PR/issue numbers still in play; anything explicitly asked to be remembered.
- **Drop:** raw tool output (logs, test output, listings, diffs, search results); superseded intermediate steps; exploratory reads that led nowhere; full contents of files already acted on. A fact recoverable by re-reading a file needs only the path, not its content.
