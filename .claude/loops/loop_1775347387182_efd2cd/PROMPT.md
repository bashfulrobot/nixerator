## Goal

Implement 5 efficiency optimizations to the `github-issue` workflow skill. These reduce unnecessary user interaction, skip irrelevant review steps, batch minor fixes, and eliminate false-positive hook warnings.

## Project Context

This is a NixOS configuration repo managed with flakes. The github-issue skill is a state-machine orchestrator for GitHub issue lifecycles.

**Key files to modify:**

| File | Purpose |
|------|---------|
| `modules/apps/cli/worktree-flow/skills/github-issue/SKILL.md` | AI orchestrator — step descriptions, routing logic |
| `modules/apps/cli/worktree-flow/scripts/github-issue.sh` | Bash CLI — state transitions, subcommands |
| `modules/apps/cli/claude-code/cfg/hooks-global.nix` | Claude Code bash-guard hook — regex for git commit/push detection |

**Conventions:**
- Commits: `type(scope): description` with `-S` signing, no AI attribution
- Nix formatting: run `nix fmt` after editing `.nix` files
- Test Nix changes: run `nix eval .#nixosConfigurations.donkeykong.config.system.build.toplevel --no-build` to check for eval errors

## Changes

Check `git log --oneline -20` first. If any of these changes are already committed, skip them and move to the next one.

### 1. Auto-classify well-specified issues (SKILL.md)

In the **Assess** step, add auto-classification logic. Currently the step always asks the user to confirm complexity. Change it so:

- If the issue body contains implementation guidance (file paths like `src/foo/bar.ts`, code blocks with snippets, or explicit acceptance criteria / step-by-step instructions), auto-classify as the appropriate level and skip user confirmation
- Log: "Auto-classified as [level] (detailed implementation guidance present). Proceeding to [target]."
- If the issue body is vague or lacks implementation signals, keep the existing behavior (present assessment, let user confirm)

This goes in the Assess section around lines 86-99 of SKILL.md.

### 2. Skip security review for UI-only changes (SKILL.md)

In the **Review (Security)** step, add a diff-profile check before suggesting `/review-security`. The logic:

- Before suggesting `/review-security`, examine the diff: `git diff <default-branch>..HEAD --name-only`
- If the diff touches **only** UI composables / UI files (e.g., Composable files, layout XML, string resources, theme files) with **no** new dependencies, network calls, file I/O, user input handling, or permission changes — auto-skip the security review
- Log: "Security review skipped — UI-only changes with no security surface."
- Add a note that the user can force security review with explicit request

This goes in the Review (Security) section around lines 180-197 of SKILL.md.

### 3. Fast-path for trivial issues (SKILL.md + github-issue.sh)

When an issue is classified as "trivial", the workflow should skip both review steps after verification.

**In github-issue.sh:**
- Add `waiting` to the allowed transitions from `verify`: change `[verify]="implement push"` to `[verify]="implement push waiting"`
- Also add `push` to allow direct push→waiting: change `[push]="review_dev"` to `[push]="review_dev waiting"`

**In SKILL.md:**
- In the Verify step, add: if `workflow_detail.complexity == "trivial"`, after verification passes, transition directly to `push` (skip reviews). After push, transition to `waiting` instead of `review_dev`.
- Document this as: "Trivial change — skipping reviews, proceeding directly to push."

### 4. Batch minor review fixes (SKILL.md)

In both **Review (Dev)** and **Review (Security)** steps, change the fix flow when verdict is `fix`:

Current behavior: each minor finding triggers a full edit → verify → push cycle.

New behavior:
- Collect ALL findings from the review
- Categorize as blocking vs minor
- Fix all minor findings in a single pass
- Run ONE verify cycle
- Do ONE push
- Log: "Batched N minor fixes into a single commit."

This applies to both review steps — update the instructions for handling `verdict=fix`.

### 5. Fix hook false positives (hooks-global.nix)

In `modules/apps/cli/claude-code/cfg/hooks-global.nix`, the bash-guard regex at line ~164:

```
grep -qE '(^|\s|;|&&|\|)git\s+(commit|push)(\s|$)'
```

This can false-positive on commands where `git commit` or `git push` appear as substrings in `gh` commands or variable assignments containing those words.

Refine the regex to:
- Still match actual `git commit` and `git push` commands
- Exclude `gh pr`, `gh issue`, and other `gh` subcommands
- Exclude patterns where `git commit`/`git push` appear inside quoted strings being assigned to variables (e.g., `PR_JSON=$(gh pr view ...)`)

After editing, run `nix fmt` on the file.

## Commit Strategy

Make one commit per change, with messages like:
- `feat(github-issue): auto-classify well-specified issues`
- `feat(github-issue): skip security review for UI-only changes`
- `feat(github-issue): fast-path trivial issues past reviews`
- `feat(github-issue): batch minor review fixes`
- `fix(claude-code): refine bash-guard regex to avoid gh false positives`
