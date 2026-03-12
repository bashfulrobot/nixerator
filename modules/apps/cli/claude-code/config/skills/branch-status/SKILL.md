---
name: branch-status
description: Show current branch status, uncommitted changes, unpushed commits, and next-step recommendations.
disable-model-invocation: true
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
