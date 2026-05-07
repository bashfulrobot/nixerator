---
name: create-kong-skill
description: Drive a new Kong CS skill end-to-end from "rough idea" to "PR open, CI running, reviewers weighing in" by orchestrating the seven kong-skill-* lifecycle verbs (init, author, finalize, lint, test, open-pr, watch-checks) plus /review-dev and /review-security. Conversational intake by default; reads what's already in context, only asks for what's missing. Triggers on /create-kong-skill, "create a kong skill", "publish a kong skill to cs-skills", "scaffold a kong-cs skill", "build a kong cs skill". Auto-applies each mutation, auto-fixes mechanical review findings inline, surfaces authorial findings as a single end-of-run prompt, and never enables auto-merge. The human reviews and merges the resulting PR by hand.
allowed-tools: ["Bash", "Read", "Edit", "Write", "Skill"]
---

# create-kong-skill

Drive a new Kong CS skill from a rough idea to a ready-for-review PR end-to-end. Orchestrates the seven `kong-skill-*` lifecycle verbs (`init`, `author`, `finalize`, `lint`, `test`, `open-pr`, `watch-checks`), the upstream drafting skill (`skill-creator:skill-creator`), and the local review skills (`/review-dev`, `/review-security`). Mutation steps (`init`, `finalize`, `open-pr`) auto-apply after a dry-run is read back. Mechanical reviewer findings (em-dashes, GNU-isms, missing `requirements`, broken links, naming) are auto-fixed and re-pushed; authorial findings (description framing, weak triggers, scope concerns) are bundled into a single end-of-run prompt. Auto-merge is never enabled. The human reviews and merges by hand.

The metaskill is pure orchestration. Every Kong lifecycle action flows through the canonical helper via the `Skill` tool. Direct shell-outs are limited to the pre-flight (cs-skills repo detection, dirty-tree check, branch creation) and the single commit before `kong-skill-open-pr`.

For one-line summaries of every consumed skill, see `references/lifecycle-map.md`. For the brief schema, see `references/brief-shape.md`.

## Invocation

```
/create-kong-skill                                       fully conversational; collect from context, ask for gaps
/create-kong-skill <skill-name>                          name pre-filled, ask for the rest
/create-kong-skill <skill-name> "<one-line purpose>"     args + one consolidated follow-up
/create-kong-skill --brief <path>                        read brief from file, ask only for gaps
/create-kong-skill --resume                              detect current state and pick up where the last run stopped
```

Trigger phrases (folded into the `description` frontmatter):

- "create a kong skill"
- "publish a kong skill to cs-skills"
- "scaffold a kong-cs skill"
- "build a kong cs skill"

## Phase 0: Pre-flight

1. Resolve the `Kong/cs-skills` clone path. Detection order:
    1. Walk up from `cwd`. For each ancestor, check for `.claude-plugin/marketplace.json` whose top-level `name` is `kong-cs`.
    2. `KONG_CS_SKILLS_DIR` environment variable.
    3. Common locations: `~/git/cs-skills`, `~/Code/cs-skills`, `~/src/cs-skills`, `~/dev/cs-skills`.
    4. Ask the user. If they don't have a clone, offer to `git clone git@github.com:Kong/cs-skills.git ~/git/cs-skills`.

    The resolved path is held in conversation context only. No on-disk cache.

2. `cd` into the resolved path. Refuse if the working tree is dirty (any untracked, staged, or unstaged change). Hint at `/commit:commit`. Do not stash silently.

3. Sync `main`:

    ```bash
    git checkout main
    git pull --ff-only
    ```

    If `pull` would not fast-forward, refuse and ask the user to reconcile.

4. Collect the brief. Read what's already in conversation context (chat, MCP outputs, prior turns, pasted snippets). Only ask for what's missing. Required fields are listed in `references/brief-shape.md`. Conversational intake walks through fields one at a time.

5. Validate the skill name against `kong-skill-init`'s rules:
    - Lowercase letters, digits, hyphens.
    - Starts with a letter.
    - Max 64 characters.
    - No `anthropic` or `claude` substring.
    - Not a reserved marketplace identifier.

    Re-ask if invalid.

6. Create the feature branch:

    ```bash
    git checkout -b feat/<skill-name>
    ```

    If a branch with that name already exists locally, switch to `--resume` semantics (see Resume below).

## Phases 1-8: The chain

Each phase invokes a downstream skill via the `Skill` tool unless noted otherwise. After each invocation, read back the relevant output to the user, then proceed to the next phase. Mutation phases (1, 3, 6) auto-apply after the dry-run is read back.

### Phase 1: Scaffold

```
Skill kong-skill-init <skill-name>
```

Reads the dry-run output. If clean, re-invokes with `--write`:

```
Skill kong-skill-init <skill-name> --write
```

Failure handling:

- Exit 3 (folder exists but is not a recognisable kong-skill plugin): ask whether to pass `--force` or pick a different name. Surface the conflict; do not auto-force.

### Phase 2: Author

```
Skill kong-skill-author --skill-name <skill-name>
```

`kong-skill-author` summarises Kong conventions and then delegates to `skill-creator:skill-creator`. Pre-load the brief from Phase 0 into the conversation before the delegation so the drafting dialog has minimal back-and-forth.

Failure handling:

- `skill-creator` not installed (delegation fails): surface the install URL (`/plugin install skill-creator`) and stop.
- Drafting dialog asks a question already answered in the brief: re-state the brief field and continue.

### Phase 3: Finalize

```
Skill kong-skill-finalize plugins/<skill-name>
```

Read back the dry-run diff. Two paths:

- **All detected tools are in `docs/ai/dep-registry.json`**: invoke with `--write`:

  ```
  Skill kong-skill-finalize plugins/<skill-name> --write
  ```

- **At least one detected tool is not in the registry**: surface the unknown-tool list. Ask the user to add registry entries (`docs/ai/dep-registry.json`, kebab-case key with `name` / `url` / optional `note`). After the user adds entries, re-run the dry-run, then `--write`.

After write, mirror the resulting `requirements` into the SKILL.md `## Requirements` section. The catalog generator reads `plugin.json`; Claude reads SKILL.md at skill load. Both must list the same requirements.

### Phase 4: Lint loop

```
Skill kong-skill-lint plugins/<skill-name>
```

Two outcomes:

- **Exit 0, no findings**: proceed to Phase 5.
- **Exit 1, findings reported**: classify each finding:
    - **Mechanical** (em-dash, GNU-only flag, missing frontmatter field, naming-rule violation, broken intra-skill link): auto-fix using `Edit` tool. Re-run the linter. Repeat up to 3 times.
    - **Unfixable**: surface and stop. The user weighs in.

After 3 unsuccessful retries on the same finding, stop and surface.

### Phase 5: Test

```
Skill kong-skill-test <skill-name> --no-open
```

Three outcomes:

- **Exit 0**: proceed to Phase 6.
- **Exit 2 (`mkdocs --strict` failure)**: surface the captured mkdocs / catalog-generator output. Attempt one auto-fix on broken links or markdown issues, re-run. On second failure, stop and surface.
- **Exit 3 (skill missing from catalog)**: surface the diagnosed wiring problem (missing marketplace entry, missing grand-meta dependency, drift in `plugin.json` `skills[]`). Re-run Phase 1's `--write` step if the wiring drifted; otherwise surface and stop.

### Phase 6: Commit and open PR

Single commit. Subject format: `feat(<skill-name>): add <skill-name> skill`. Body: one paragraph from the brief's `purpose` field. No `Co-Authored-By`, no AI attribution (per CLAUDE.md).

```bash
git add plugins/<skill-name> .claude-plugin/marketplace.json plugins/cs-skills/.claude-plugin/plugin.json
git commit -m "feat(<skill-name>): add <skill-name> skill"
```

Then:

```
Skill kong-skill-open-pr
```

Read back the dry-run state and proposed PR body. If clean, re-invoke with `--apply`:

```
Skill kong-skill-open-pr --apply
```

Capture the PR URL. Failure handling:

- Exit 4 (gh auth missing or SAML not authorised for Kong): ask the user to run `gh auth login` and `gh auth refresh -h github.com -s read:org` if needed. Stop until resolved.
- State 7 (PR already open): treat as resume; print URL and continue to Phase 7.
- State 8 (PR closed/merged): refuse. The user weighs in.

### Phase 7: Watch and review (concurrent)

#### 7a: Watch CI (background)

```
Skill kong-skill-watch-checks --watch --interval 30
```

Run via `Bash run_in_background`. Surface terminal-state output and any scanner failures inline. Do not paraphrase scanner log content; relay the `gh run view <run-id> --log-failed` hint.

#### 7b: Review (foreground, sequential)

```
Skill review-dev
```

Wait for completion. Then:

```
Skill review-security
```

Wait for completion.

For each finding from either review:

1. Classify as **mechanical** or **authorial** (see classification rules in the next section).
2. **Mechanical**: auto-fix using `Edit`, then `git add` + `git commit -m "fix(<skill-name>): address review finding"` + `git push`. Do not re-run the reviews automatically; the user merges by hand and the next iteration of the metaskill (or the human) handles further passes.
3. **Authorial**: collect into the bundled prompt for Phase 8.

If a "mechanical" finding survives one auto-fix-then-push cycle without being closed by the next review pass, reclassify as authorial.

### Phase 8: Hand-off

Print:

- The PR URL.
- The terminal CI scanner state (from Phase 7a).
- The bundled authorial-finding prompt, if any:

```
/review-dev and /review-security flagged N judgment calls. Want me to take a swing at any?
  [1] description on line K over-promises ("always", "every")
  [2] trigger phrase "kong stuff" is too broad
  [3] skill should arguably be split: scaffolding vs. publishing
Reply with the numbers to address (e.g., "1,2"), "all", or "none".
```

For each selected finding, make the change, re-commit, re-push. The metaskill exits after the user replies; it does not re-run the reviews and never enables auto-merge.

## Reviewer-finding classification

When `/review-dev` or `/review-security` reports a finding, classify it:

**Mechanical** (auto-fix + commit + push):

- Em-dash (U+2014) anywhere in skill content.
- GNU-only shell flag (`sed -i ''`, `grep -P`, `readlink -f`, etc.); see `kong-skill-lint`'s denylist.
- Missing or stale `requirements` entry.
- Broken intra-skill markdown link.
- Naming-rule violation.
- Missing frontmatter field.

**Authorial** (surface, do not auto-fix):

- "Description over-promises" (uses absolutes like "always", "every", "perfect", "complete").
- "Trigger phrasing is weak" (too broad, too narrow, ambiguous).
- "Skill should be split" (scope concern).
- "Skill should be merged with another" (overlap concern).
- "Description doesn't match the actual workflow" (drift between framing and steps).
- Anything tagged `[authorial]` or `[judgment]` by the reviewer.

When in doubt, classify as authorial. False mechanical → silent auto-fix that may be wrong. False authorial → user sees the finding in Phase 8 and decides. The bias is toward "ask".

## Resume

`--resume` (or auto-detected on re-invocation while a `feat/<name>` branch is checked out): inspect repo state and skip already-completed phases.

| State observed | Skip to |
|---|---|
| Branch `feat/<name>` exists, tree clean | Phase 1 (idempotent re-run; "already wired" exits cleanly) |
| `plugins/<name>/skills/<name>/SKILL.md` body is non-placeholder | Phase 3 |
| `plugin.json` has non-empty `requirements` | Phase 4 |
| Last `kong-skill-lint` was clean (no findings) | Phase 5 |
| `mkdocs --strict` build last passed | Phase 6 |
| PR exists for this branch (`gh pr view`) | Phase 7 |

Placeholder-body detection is heuristic: if the SKILL.md body still contains the literal scaffold sentinel that `kong-skill-init` writes when it generates a draft, treat as not-drafted. Otherwise treat as drafted.

## Failure modes

- **Dirty tree on entry.** Refuse, hint at `/commit:commit`. Do not stash silently.
- **No `Kong/cs-skills` clone found.** Ask once; offer to clone to `~/git/cs-skills` if the user agrees.
- **`gh` not authenticated for the Kong org.** `kong-skill-watch-checks`, `kong-skill-open-pr`, and the review skills all fail. Surface once at Phase 6 and stop.
- **`skill-creator` not installed.** `kong-skill-author` exits without delegating. Surface install URL and stop.
- **Unknown tool detected by `kong-skill-finalize`.** User-gated: open `dep-registry.json`, add the entry, re-run dry-run.
- **Lint loop exceeds 3 retries.** Stop, surface the remaining findings, ask the user to weigh in.
- **`mkdocs --strict` fails on a benign warning.** Stop after one auto-fix attempt. The fix lives in source markdown, not in this skill.
- **Scanner failure on Phase 7a.** Surface, route to Kong's `docs/mkdocs/docs/security.md` playbook (fix / accept-risk / bypass-merge). The metaskill does not pick a path.
- **Reviewer mechanical-fix loop oscillates.** If a mechanical finding survives one auto-fix-then-push cycle, reclassify as authorial and surface in Phase 8.

## Outputs

- One PR on `Kong/cs-skills`, ready for human review and merge.
- Auto-merge always disabled.
- Local branch `feat/<name>` left checked out so you can `gh pr view --web`.
- Phase 8 chat output covers the PR URL, the final CI scanner state, and the bundled authorial-finding prompt (if any).

## References

- `references/lifecycle-map.md`: one-line summary of every consumed skill.
- `references/brief-shape.md`: the brief schema.
