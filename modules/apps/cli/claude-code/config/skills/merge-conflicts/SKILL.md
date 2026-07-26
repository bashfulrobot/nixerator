---
name: merge-conflicts
description: >-
  Resolve git merge conflicts with the mergiraf syntax-aware merge driver rather
  than hand-editing conflict markers, including the GitHub-PR path where
  server-side merges bypass the driver entirely.
when_to_use: >-
  Fires when `git status` shows unmerged paths; when a merge, rebase,
  cherry-pick, revert, or stash pop stops with conflicts; when a file contains
  conflict markers; when a PR reports "conflicts must be resolved" or "this
  branch has conflicts"; or when Dustin says rebase onto main, resolve the
  conflicts, fix the merge, or sort out the conflict. Read this BEFORE editing
  any conflict marker by hand -- `mergiraf solve <file>` is always the first
  move.
allowed-tools: ["Bash", "Read", "Edit", "Grep"]
---

# Merge Conflicts (mergiraf)

`mergiraf` is installed globally as a syntax-aware merge driver and runs automatically for every `git merge`, `rebase`, `cherry-pick`, `revert`, and `stash pop` on supported file types (Nix, Kotlin, TS/JS, Go, Rust, Python, TOML, YAML, JSON, HCL, Markdown, etc. — full list in `~/.config/git/attributes`). Conflict style is `diff3` so mergiraf can read all three sides.

- **Do not hand-edit conflict markers as a first move.** If `git status` shows unmerged paths after a rebase/merge, run `mergiraf solve <file>` first — it retries the syntactic merge on a single file and often clears markers without manual work.
- **Genuine conflicts**: if mergiraf left markers, that's usually a real semantic conflict. Resolve by reading both sides, not by deleting one. Re-run `mergiraf solve` after partial edits.
- **GitHub PR conflicts run server-side and bypass mergiraf.** The GitHub "Merge pull request" button does not invoke client-side merge drivers. When a PR shows "conflicts must be resolved", the workflow is: `gh pr checkout <num>` → `git rebase origin/main` (mergiraf engages) → `mergiraf solve` on any leftovers → `git push --force-with-lease`. GitHub then fast-forwards cleanly.
- **Project-local extensions**: `*.gradle.kts` and `*.kts` are not in mergiraf's defaults but parse with the Kotlin grammar. Repos that need them (e.g. upsight) carry their own `.gitattributes` adding those globs.

## Related constraint

Force-pushes and other destructive git operations always need explicit
confirmation from Dustin. The `git push --force-with-lease` step above is part
of the documented PR-conflict workflow, but confirm before running it.
