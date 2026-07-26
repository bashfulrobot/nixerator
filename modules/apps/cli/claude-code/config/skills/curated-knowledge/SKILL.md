---
name: curated-knowledge
description: >-
  Where durable knowledge belongs — skill, `.claude/docs/` topic file, a skill's
  `references/`, or auto-memory — plus the thin-CLAUDE.md table-of-contents
  protocol. Use when writing or editing a project CLAUDE.md or `.claude/docs/`
  file, choosing between a skill and a doc and a memory entry, when a CLAUDE.md
  grows past ~100 lines, or when the user says document this, write this down,
  remember this, or add this to CLAUDE.md.
allowed-tools: ["Read", "Write", "Edit", "Glob", "Grep"]
---

# Project context: thin-CLAUDE.md protocol

Each project's `CLAUDE.md` is a thin **table of contents** over per-topic detail files at `.claude/docs/<topic>.md` (preferred) or `docs/claude/<topic>.md`. The root file is loaded on every turn, so it stays small; detail loads on demand.

**Reading.** TOC entries use imperative voice: *"When [trigger], read `.claude/docs/foo.md`."* When the trigger fires for your task, **read the file before acting** — do not infer from the index entry alone. Detail files are single-hop: they never link to other detail files.

**Writing.** When you learn something curated, stable, and PR-reviewable that future sessions will need:

1. Create or extend `.claude/docs/<topic>.md`. One topic per file. Filename matches the topic.
2. Open the file with a one-line summary describing what it covers.
3. Add a one-line entry to the project `CLAUDE.md` Topics section in imperative voice.
4. Keep project `CLAUDE.md` under ~100 lines. If it grows, the cure is more topic files, not longer entries.

**Don't put here:** session-derived facts about user preferences or in-flight context (those go to `~/.claude/projects/.../memory/` auto-memory); information already in code or git history; speculative ideas.

# Where curated knowledge goes

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
