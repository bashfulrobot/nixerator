# SessionStart: report this checkout's relationship to its upstream branch
# and, in a linked worktree ONLY, silently align it.
#
# Runs on every session start, in whatever directory that session's cwd
# happens to be -- including the shared PRIMARY checkout of any repo (epic
# #252 invariant 1, same as guard-primary-tree-write.sh). The original
# version of this hook ran `git reset "origin/$branch"` (mixed, not --hard)
# unconditionally whenever local was purely behind, with no regard for which
# checkout it was in and no dirty-tree check.
#
# A mixed reset never touches files on disk -- it only moves HEAD and the
# index -- but that is exactly what makes it dangerous here. If the checkout
# already had older, legitimately clean content sitting in a file that a
# newly-fetched commit changed, the reset silently fast-forwards HEAD past
# that commit while the file on disk stays put, and every diff/status tool
# afterward reports that file as "modified" -- indistinguishable from someone
# manually reverting the commit's change. That happened for real: a
# [git-sync] reset landed on a primary checkout the moment a PR merged, and
# the files that PR touched looked like a hand-authored revert for hours
# afterward, with no commit, stash, or reflog entry pointing at an author --
# because there wasn't one; the working tree just held pre-merge content the
# whole time and the reset moved HEAD out from under it.
#
# Fix: only ever auto-reset a LINKED worktree (git-dir != git-common-dir),
# which is exclusively owned by whichever task created it -- no concurrent
# session has a legitimate reason to depend on that worktree's HEAD staying
# put, so silently aligning it to origin is the same convenience the original
# hook intended. The PRIMARY checkout is report-only: never reset, regardless
# of ahead/behind state, matching that checkout's "read-only for agent task
# work" contract enforced elsewhere in this config. And even in a worktree,
# skip the auto-reset if the tree is dirty -- resetting a dirty worktree
# reproduces the exact same stale-content-vs-new-HEAD illusion this fix
# exists to prevent, just one level down.

git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
branch="$(git rev-parse --abbrev-ref HEAD)"
git fetch origin >/dev/null 2>&1 || exit 0

local_only="$(git log "origin/$branch..$branch" --oneline 2>/dev/null)"
remote_only="$(git log "$branch..origin/$branch" --oneline 2>/dev/null)"

if [ -n "$local_only" ] && [ -n "$remote_only" ]; then
  echo "[git-sync] Diverged -- local and remote both have commits. Resolve manually."
  exit 0
fi

if [ -z "$remote_only" ]; then
  [ -n "$local_only" ] && echo "[git-sync] Unpushed local commits on $branch"
  exit 0
fi

# Only remote_only is non-empty past this point: local is purely behind.
gd="$(git rev-parse --path-format=absolute --git-dir 2>/dev/null)"
gcd="$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null)"
is_primary=false
[ -n "$gd" ] && [ -n "$gcd" ] && [ "$gd" = "$gcd" ] && is_primary=true

behind_count="$(printf '%s\n' "$remote_only" | wc -l)"
dirty_count="$(git status --porcelain 2>/dev/null | wc -l)"

if [ "$is_primary" = true ]; then
  echo "[git-sync] Primary checkout is $behind_count commit(s) behind origin/$branch -- not auto-aligning (shared checkout, read-only for agent task work). Run 'git pull' yourself, or work in a worktree."
  exit 0
fi

if [ "$dirty_count" -gt 0 ]; then
  echo "[git-sync] $behind_count commit(s) behind origin/$branch -- not auto-aligning ($dirty_count uncommitted change(s) present)."
  exit 0
fi

git reset "origin/$branch" >/dev/null 2>&1
echo "[git-sync] Aligned git state with origin/$branch"
