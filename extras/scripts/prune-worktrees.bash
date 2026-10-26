#!/usr/bin/env bash
# prune-worktrees: remove the linked worktrees under .claude/worktrees whose
# branch already has a merged PR, and delete their local branch.
#
#   prune-worktrees          dry run: list what would be removed and what is kept
#   prune-worktrees --yes    remove them
#
# Run it from the primary checkout. A session cannot remove the worktree it
# stands in, so this is the cleanup that dk:git-cleanup leaves to you.
#
# A worktree is removed only when all of these hold:
#   - it lives under <primary>/.claude/worktrees
#   - it has no uncommitted changes (an untracked ./result link is ignored)
#   - its branch has a merged PR
#   - the branch tip is the commit that PR merged, so nothing was added after
set -euo pipefail

apply=0
[ "${1:-}" = "--yes" ] && apply=1

git_dir=$(cd "$(git rev-parse --git-dir)" && pwd -P)
common_dir=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
if [ "$git_dir" != "$common_dir" ]; then
  echo "prune-worktrees: run this from the primary checkout, not a linked worktree" >&2
  exit 1
fi

primary=$(git rev-parse --show-toplevel)
git worktree prune

removed=0
kept=0
path=""
branch=""

consider() {
  local wt="$1" br="$2"
  case "$wt" in
  "$primary"/.claude/worktrees/*) ;;
  *) return 0 ;;
  esac

  local reason=""
  if [ -z "$br" ]; then
    reason="detached HEAD"
  elif [ -n "$(git -C "$wt" status --porcelain | grep -v '^?? result$' || true)" ]; then
    reason="uncommitted changes"
  else
    local merged_oid tip
    merged_oid=$(gh pr list --head "$br" --state merged --json headRefOid --jq '.[0].headRefOid // empty')
    tip=$(git -C "$wt" rev-parse HEAD)
    if [ -z "$merged_oid" ]; then
      reason="no merged PR"
    elif [ "$merged_oid" != "$tip" ]; then
      reason="commits after the merged PR"
    fi
  fi

  if [ -n "$reason" ]; then
    echo "keep    $wt ($br): $reason"
    kept=$((kept + 1))
    return 0
  fi

  if [ "$apply" = 1 ]; then
    git worktree remove --force "$wt"
    git branch -D "$br" >/dev/null
    echo "removed $wt ($br)"
  else
    echo "would remove $wt ($br)"
  fi
  removed=$((removed + 1))
}

# Porcelain output is blocks separated by a blank line: worktree, HEAD, branch.
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
  "worktree "*) path="${line#worktree }" ;;
  "branch refs/heads/"*) branch="${line#branch refs/heads/}" ;;
  "")
    [ -n "$path" ] && consider "$path" "$branch"
    path=""
    branch=""
    ;;
  esac
done < <(git worktree list --porcelain)
[ -n "$path" ] && consider "$path" "$branch"

if [ "$apply" = 1 ]; then
  echo "$removed removed, $kept kept"
else
  echo "$removed would be removed, $kept kept (run with --yes to remove)"
fi
