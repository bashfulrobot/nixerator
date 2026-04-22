## Completion Criteria

The task is complete when ALL of the following are true:

### 1. Auto-classify (SKILL.md)

- The Assess step in `modules/apps/cli/worktree-flow/skills/github-issue/SKILL.md` contains logic for auto-classifying issues when the issue body has implementation guidance (file paths, code blocks, acceptance criteria)
- The auto-classify path explicitly skips user confirmation
- The fallback (vague issues) still presents the assessment for user confirmation

### 2. Skip security review for UI-only (SKILL.md)

- The Review (Security) step in SKILL.md contains a diff-profile check
- UI-only changes (no new deps, network calls, file I/O, input handling) are auto-skipped with a log message
- A force-override option is documented

### 3. Fast-path trivial (SKILL.md + github-issue.sh)

- In `modules/apps/cli/worktree-flow/scripts/github-issue.sh`, the `VALID_TRANSITIONS` for `verify` includes `waiting` (in addition to `implement` and `push`)
- In `modules/apps/cli/worktree-flow/scripts/github-issue.sh`, the `VALID_TRANSITIONS` for `push` includes `waiting` (in addition to `review_dev`)
- In SKILL.md, the Verify step has conditional logic: if complexity is trivial, skip reviews and go to push then waiting

### 4. Batch minor review fixes (SKILL.md)

- Both Review (Dev) and Review (Security) steps in SKILL.md describe batching: collect all findings, fix in one pass, single verify-push cycle
- The word "batch" or "single pass" appears in both review sections

### 5. Hook regex fix (hooks-global.nix)

- In `modules/apps/cli/claude-code/cfg/hooks-global.nix`, the bash-guard regex for git commit/push detection has been refined
- The new regex does NOT match `gh pr` or `gh issue` commands
- The new regex still matches actual `git commit` and `git push` commands

### 6. No Nix eval errors

- Running `nix eval .#nixosConfigurations.donkeykong.config.system.build.toplevel --no-build` does not produce errors (exit code 0)

### 7. All changes committed

- `git log` shows commits for the implemented changes
- No uncommitted modifications remain in the working tree
