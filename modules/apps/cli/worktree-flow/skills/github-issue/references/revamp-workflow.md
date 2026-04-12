# Revamp Workflow (PR Review Loop)

When a PR receives "changes requested", Claude re-enters the implementation cycle to address the feedback. This can happen multiple times — each round follows the same pattern.

## Entry Condition

State detection finds a PR with `reviewDecision: CHANGES_REQUESTED`. In worktree mode, the bash script may also inject review comments into the system prompt.

## Procedure

### 1. Fetch Review Feedback

```bash
# Get all reviews with CHANGES_REQUESTED state
gh pr view <pr_url> --json reviews --jq '.reviews[] | select(.state == "CHANGES_REQUESTED")'

# Get individual review comments (inline code comments)
gh api repos/{owner}/{repo}/pulls/{pr_number}/comments --jq '.[] | {path, line, body, created_at}'
```

Read both the review-level comments (high-level feedback) and inline code comments (specific line feedback).

### 2. Evaluate Feedback Technically

**Invoke `superpowers:receiving-code-review`** before making changes.

This skill enforces technical rigor: don't blindly agree with all feedback. For each piece of feedback:
- Does the suggestion improve the code?
- Is there a technical reason the current approach is better?
- Is the feedback based on a misunderstanding of the codebase?

If feedback is questionable, push back with evidence in the PR comment. If it's valid, address it.

### 3. Implement Changes

Re-enter the IMPLEMENT state with review context:
- Work through each actionable review item
- Make focused commits — one per review concern where practical
- Use commit messages that reference the review (e.g., `fix(auth): :bug: handle edge case from review`)
- Follow all conventions from conventions.md

### 4. Verify

**Invoke `superpowers:verification-before-completion`** after making changes.

Run tests, linters, build. Evidence before claims.

### 5. Push Updates

Push directly to the existing PR branch:

```bash
git push origin <branch>
```

Claude can push during REVAMP because the PR already exists — the bash script only creates the initial PR.

### 6. Comment on PR

After pushing, leave a comment summarizing what was addressed:

```bash
gh pr comment <pr_url> --body "Addressed review feedback:
- <item 1>
- <item 2>
- <item 3>"
```

### 7. Request Re-review (optional)

If the reviewer should be notified:

```bash
gh pr edit <pr_url> --add-reviewer <reviewer>
```

Or simply note in the comment that changes are ready for re-review.

## Multiple Review Rounds

The same cycle repeats if the reviewer requests more changes. Each round:
1. Fetch latest review feedback (filter by date to see only new comments)
2. Evaluate technically
3. Implement + verify + push
4. Comment

There's no limit on rounds — the cycle continues until the PR is approved or the user decides to close it.

## CI Failures During Revamp

If CI fails after pushing revamp changes:
1. Fetch check details: `gh pr checks <pr_url>`
2. Identify failing checks
3. Fix the failures (this is still part of the REVAMP cycle)
4. Push again
5. Monitor checks before commenting that changes are ready

## Merge Conflicts During Revamp

If the PR develops merge conflicts while addressing review feedback:
1. Rebase onto the default branch: `git fetch origin && git rebase origin/<default>`
2. Resolve conflicts if able
3. If conflicts need human input, report conflicting files and stop
4. After resolution: `git push --force-with-lease origin <branch>`

Use `--force-with-lease` (not `--force`) to avoid overwriting concurrent changes.
