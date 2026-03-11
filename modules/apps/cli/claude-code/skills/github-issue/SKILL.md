---
name: github-issue
description: Work a GitHub issue end-to-end: branch, implement, commit, PR, then post-merge cleanup.
argument-hint: "[--auto] <issue-number>"
allowed-tools: ["Bash", "Read", "Write", "Edit", "Grep", "Glob", "Agent", "AskUserQuestion"]
---

## Commit conventions

Format: `<type>(<scope>): <emoji> <description>`

- Type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|security|deps
- Scope: REQUIRED, lowercase, kebab-case.
- Emoji: AFTER colon (e.g., `fix(claude-code): 🐛 resolve widget crash`).
- Subject: imperative, <72 chars.
- Sign with `git commit -S`. Split unrelated changes atomically.
- Never add Co-Authored-By or any AI attribution.

Type to emoji: feat:✨ fix:🐛 docs:📝 style:🎨 refactor:♻️ perf:⚡ test:✅ build:👷 ci:💚 chore:🔧 revert:⏪ security:🔒 deps:⬆️

## Modes

- **Interactive** (default): Pauses for user input when the issue number is missing. Asks the user to pick from open issues.
- **Autonomous** (`--auto`): Requires an issue number. Skips all confirmation prompts. Implements, commits, pushes, and creates the PR without stopping. Still does not merge (user merges). If no issue number is provided with `--auto`, error out immediately.

## Workflow

This skill has two phases. On invocation, detect which phase applies.

### Phase detection

1. Parse `$ARGUMENTS` for flags and issue number. If `--auto` is present, enable autonomous mode.
2. If no number given:
   - **Interactive**: list open issues (`gh issue list --state open`) and ask the user to pick one. Stop until they respond.
   - **Autonomous**: error out with "Issue number required in --auto mode."
3. Check if a PR already exists for this issue: `gh pr list --search "<number>" --json number,state,headRefName`
4. If a merged PR exists, go to **Phase 2**. If an open PR exists, tell the user it is awaiting review and provide the URL, then stop. Otherwise, proceed to **Phase 1**.

### Phase 1: Implement and PR

1. Fetch issue details: `gh issue view <number>`
2. Detect default branch: `default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||'); default_branch="${default_branch:-main}"`
3. Create branch from default branch: `fix/<slug>` or `feat/<slug>` based on issue content (kebab-case from title). Checkout the new branch.
4. Implement the fix or feature. Research the codebase, edit files, run builds as needed.
5. Stage and commit following the commit conventions above:
   - Include `Closes #<number>` in the commit body.
   - Split into atomic commits if changes span unrelated areas.
6. Push branch: `git push -u origin <branch>`
7. Create PR via `gh pr create`:
   - Title: short, <70 chars.
   - Body format:
     ```
     ## Summary
     - <bullet points>

     ## Test plan
     - [ ] <checklist items>

     Closes #<number>
     ```
8. Comment on the issue linking the PR: `gh issue comment <number> --body "PR #<pr-number> opened to address this."`
9. Output the PR URL. Tell the user to review and merge. Do not merge.
   - **Interactive**: **STOP** here and wait for the user.
   - **Autonomous**: Proceed directly to a brief summary of what was done, then finish. The user will re-invoke with the same issue number for Phase 2 cleanup after merging.

### Phase 2: Post-merge cleanup

Triggered when re-invoked and a merged PR exists for the issue.

1. Detect default branch (same as Phase 1 step 2).
2. Switch to default branch and pull: `git checkout $default_branch && git pull`
3. Delete local branch if it still exists: `git branch -d <branch>` (ignore errors if already gone).
4. Delete remote branch if it still exists: `git push origin --delete <branch>` (ignore errors if already deleted by merge).
5. Comment on the issue: `gh issue comment <number> --body "Resolved in #<pr-number>. <brief summary of what was done>."`
6. Comment on the PR: `gh pr comment <pr-number> --body "Merged and cleaned up. <brief summary of changes>."`
7. Confirm cleanup is complete.

## Constraints

- All GitHub operations use the `gh` CLI. Never construct raw API URLs.
- Never merge PRs. The user handles merges.
- Never add Claude attribution anywhere (commits, PRs, issue comments).
