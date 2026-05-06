# claude-code module

Nix-managed Claude Code configuration: settings, hooks, agents, skills, MCP
servers, plugins, status line. Built around the thin-CLAUDE.md protocol; most
behaviour is enforced via hooks rather than left to discipline.

## External best-practices audit

Last evaluated: **2026-05-05** against
<https://colobu.com/2026/01/01/40+%20Claude%20Code%20Tips%EF%BC%9A%20From%20Basics%20to%20Advanced/index/>
("40+ Claude Code Tips: From Basics to Advanced").

**Reassess by: 2026-08-05** (3 months). The Claude Code surface and community
practice change quickly; refetch the article (or successor) and re-run this
audit. If the article is gone, search for an updated tips list and substitute.

### Already covered (often more rigorously than the article)

| Tip | Where |
|---|---|
| 0. Custom status line | `statusline.sh` -- model, tokens, %used/remain, thinking, plus 5h / weekly / extra-credits progress bars from `api.anthropic.com/api/oauth/usage` |
| 3. Decompose problems | Plan/Explore agents + `superpowers:writing-plans`/`executing-plans` |
| 4. Git/gh delegation with safety | `Bash(gh *)` / `Bash(git *)` allowed; `--no-verify` and bare `--force` hard-blocked by PostToolUse hook (`config/settings.json` -- bash-guard) |
| 5. Fresh context | `cleanupPeriodDays: 15`, intent logs auto-pruned at +15d |
| 8. Compact context | `PreCompact` hook + REAP `/reap.knowledge` for handoff |
| 12. Invest in workflow | This entire Nix module |
| 13. Search history | `UserPromptSubmit` writes JSONL to `~/.claude/intent-logs/{session_id}.jsonl` |
| 14. Multitasking / tmux | tmux-claude hook on every event (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `Stop`, `SubagentStart`, `PreCompact`, `Elicitation`, `SessionEnd`) |
| 16. Worktrees | `additionalDirectories` includes `~/git/.worktrees`; `superpowers:using-git-worktrees` + `hack` skill |
| 19. Markdown everywhere | All agents/skills/CLAUDE.md |
| 24. Realpath | `Bash(realpath *)` allowed |
| 25. CLAUDE.md vs skills vs commands vs plugins | Documented in `~/.claude/CLAUDE.md` ("Where curated knowledge goes") |
| 26. Interactive PR reviews | `/review-dev`, `/review-security`, `/review`, `/ultrareview` |
| 27. Research tool | gitmcp + context7 + qmd + chrome-devtools + playwright MCPs |
| 28. Output verification | `superpowers:verification-before-completion` (mandatory) |
| 29. DevOps automation | `devops` agent + `fluxcd` + `gitops-*` skills |
| 30. Keep CLAUDE.md simple | Thin-CLAUDE.md protocol is the documented standard |
| 33. Audit approved commands | Stronger than `cc-safe`: dangerous patterns blocked at hook time. `rm`/`sudo`/`kill`/`pkill` require ask; `nixos-rebuild switch/boot/test` and `nix-collect-garbage` denied |
| 34. TDD | `superpowers:test-driven-development` (rigid) + `testing` agent |
| 38. Readline/EDITOR | tmux/ghostty allowed; `EDITOR` set in fish config |
| 39. Plan before prototype | `superpowers:brainstorming` mandatory; `superpowers:writing-plans` before code |
| 41. Automation of automation | Realised in this module |

### Partially covered

- **Tip 17 -- Exponential backoff for long jobs.** `Monitor` / `run_in_background` exist; no documented convention.
- **Tip 32 -- Choose right abstraction level.** Implicit in Plan/Explore agents; not codified.
- **Tip 35 -- Brave in unknown territory.** Global CLAUDE.md emphasises *epistemic discipline* (don't assume); doesn't explicitly encourage iterative exploration.
- **Tip 36 -- Background processes.** Default `Ctrl+B`; no convention.
- **Tip 40 -- Simplify overcomplicated code.** `simplify` skill exists; not auto-invoked after large diffs.

### Not covered

- **Tip 2 -- Voice / whisper.** No local transcription set up in this module.
- **Tip 11 -- Gemini CLI fallback for blocked sites.** `GEMINI_API_KEY` is wired (`default.nix` env block), but no `reddit-fetch`-style skill wraps the Gemini CLI for Cloudflare/Reddit-blocked URLs.
- **Tip 15 -- Slim system prompt by patching CLI bundle.** Skipped intentionally -- conflicts with Nix's read-only store and version pinning.
- **Tip 21 -- Containerised `--dangerously-skip-permissions`.** `skipDangerousModePermissionPrompt: true` is set without container isolation. Defensible under the documented threat model (single-user host, git-crypt secrets), but worth re-checking each cycle.
- **Tip 23 -- Clone / half-clone conversations.** No script or `dx` plugin equivalent.
- **Tip 9 -- Verification via scripted tmux send.** tmux-claude hooks exist; no documented send-and-verify pattern.

### Suggested low-effort wins (next pass)

1. **Gemini-CLI fetch skill** for Reddit/Cloudflare-blocked pages (Tip 11). `GEMINI_API_KEY` already exported; skill is ~20 lines.
2. **Document exponential-backoff convention** in global CLAUDE.md "Use of tools" (Tip 17). `ScheduleWakeup` / `Monitor` already support it; only the convention is missing.
3. **Annotate `skipDangerousModePermissionPrompt: true`** (`config/settings.json`) with a comment explaining the single-user threat-model rationale (Tip 21), or gate it to non-headless hosts only.

## Re-audit procedure

1. Refetch the article (or current successor list).
2. Diff against this README's "Already covered / Partial / Not covered"
   sections.
3. Update the "Last evaluated" date and "Reassess by" date at the top.
4. Update the project memory at
   `~/.claude/projects/-home-dustin-git-nixerator/memory/project_claude_code_eval.md`
   so future sessions surface the new review date.
