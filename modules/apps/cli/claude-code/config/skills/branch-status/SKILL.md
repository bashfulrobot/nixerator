---
name: branch-status
description: Report the current branch's state -- uncommitted changes, unpushed commits, position relative to the default branch -- and recommend the next step. Read-only git plumbing, formatted for a human.
when_to_use: >-
  Use when the user asks where a branch stands or what is left to do with it:
  "where am I", "what's my branch status", "what have I got uncommitted", "am I
  pushed", "did I push this", "anything unpushed", "what's left on this branch",
  "/branch-status". Also use when picking work back up after a break and the
  branch state is unknown. For every task worktree on the machine rather than
  just the current directory, use fleet-status instead.
effort: low
model: haiku
allowed-tools: ["Bash", "Read"]
---

## Process

1. Run all checks:

```bash
# Detect default branch dynamically
default_branch=$(git symbolic-ref refs/remotes/origin/HEAD 2>/dev/null | sed 's|refs/remotes/origin/||')
default_branch="${default_branch:-main}"

branch=$(git rev-parse --abbrev-ref HEAD)
echo "Branch: $branch"
echo ""

# Uncommitted changes
changes=$(git status --porcelain)
if [[ -n "$changes" ]]; then
  count=$(echo "$changes" | wc -l)
  echo "Uncommitted changes: $count files"
  echo "$changes"
else
  echo "Working tree clean."
fi
echo ""

# Unpushed commits
if git rev-parse --verify "origin/$branch" >/dev/null 2>&1; then
  unpushed=$(git log "origin/$branch..$branch" --oneline)
  if [[ -n "$unpushed" ]]; then
    echo "Unpushed commits:"
    echo "$unpushed"
  else
    echo "Up to date with origin/$branch."
  fi
else
  echo "No remote tracking branch for $branch."
fi
echo ""

# Ahead/behind default branch (if not on it)
if [[ "$branch" != "$default_branch" ]]; then
  counts=$(git rev-list --left-right --count "$default_branch...$branch" 2>/dev/null || true)
  if [[ -n "$counts" ]]; then
    behind=$(echo "$counts" | awk '{print $1}')
    ahead=$(echo "$counts" | awk '{print $2}')
    echo "vs $default_branch: $ahead ahead, $behind behind"
  fi
fi
```

2. Provide a summary with recommendations:

**If on default branch with uncommitted changes:**

- Suggest creating a feature branch retroactively: `git switch -c feat/<name>` (uncommitted changes carry over)

**If on default branch, clean:**

- Note that the default branch is fine for quick one-liner fixes
- For larger work, suggest `git switch -c feat/<name>`

**If on a feature branch:**

- If behind default branch: suggest rebasing with `git rebase <default_branch>`
- If unpushed commits exist: suggest pushing
- If clean and up to date: suggest it may be ready to merge
