# Domain Pitfalls

**Domain:** Git worktree workflow CLI tools with Claude Code integration
**Researched:** 2026-03-11
**Confidence:** HIGH (multiple sources; several verified against official docs and real issue trackers)

---

## Critical Pitfalls

Mistakes that cause rewrites, data loss, or broken git state.

---

### Pitfall 1: Orphaned Worktrees from Partial Failure

**What goes wrong:** If a worktree setup sequence fails mid-way (e.g., `git worktree add` succeeds but a subsequent step like git-crypt unlock or state file write throws an error), the worktree directory and its `.git/worktrees/` metadata entry are left permanently registered. Subsequent runs with the same issue number generate a *new* random-ish name instead of reusing the old path. You accumulate phantom worktrees that block branch operations.

**Why it happens:** `git worktree add` has no rollback. The `.git/worktrees/<name>/` entry and the working directory both persist until explicitly removed. `writeShellApplication` uses `set -euo pipefail` strict mode by default, so any subsequent command failure halts the script without cleanup.

**Consequences:**
- `git branch -d fix/issue-42` fails with "cannot delete branch used by worktree"
- Disk fills up (each worktree is a full checkout)
- `git worktree list` shows ghost entries that confuse state detection logic

**Prevention:**
- Register a `trap cleanup EXIT` immediately after `git worktree add` succeeds. The cleanup function removes the worktree with `git worktree remove --force "$wt_path"` if the script exits non-zero before completing setup.
- Write a `WORKTREE_READY` flag into the state file only as the *last* step of setup. On resume/recovery, absence of this flag signals incomplete setup to clean up and retry.
- Document `git worktree prune` as a recovery command in the tool's help output.

**Detection:**
- `git worktree list` shows paths that no longer contain the expected state file
- Branch deletion errors mentioning worktree paths

**Phase mapping:** Phase 1 (worktree creation) and Phase 3 (cleanup). The trap must be wired during the creation phase; the cleanup command must be validated in the cleanup phase.

**Source:** [Worktree bootstrap failures leak orphaned directories](https://github.com/anomalyco/opencode/issues/14648), [git-worktree docs](https://git-scm.com/docs/git-worktree), [Stale worktrees in Claude Code](https://github.com/anthropics/claude-code/issues/26725)

---

### Pitfall 2: Manual Directory Deletion Leaves Dangling Branch References

**What goes wrong:** If a user manually `rm -rf`s the worktree directory (instead of using `git worktree remove`), git retains the `.git/worktrees/<name>/` entry. Any later attempt to delete the feature branch returns: `error: Cannot delete branch 'fix/issue-42' checked out at '/path/that/no/longer/exists'`.

**Why it happens:** Git cannot detect that the directory was externally deleted until `git worktree prune` is run. The branch remains "checked out" in git's view.

**Consequences:**
- Feature branches cannot be deleted without force (`-D`), defeating safe-delete protection
- The cleanup phase of the tool appears to hang or error on branch deletion

**Prevention:**
- The cleanup function must always go through `git worktree remove` first, then `git worktree prune`, *then* attempt branch deletion.
- Mimic the pattern in `gcom`'s `cmd_finish`: unset upstream tracking before `branch -d` to avoid upstream merge-status confusion. See lines 290-296 in `modules/apps/cli/git/default.nix`.
- Add a prune step at the start of both `github-issue` and `hack` to silently clean stale entries from previous interrupted runs.

**Detection:**
- Branch delete fails with path reference that doesn't exist
- `git worktree list` shows `(bare)` or missing directory

**Phase mapping:** Phase 3 (cleanup). Prune should run at the start of every cleanup function, not just when errors occur.

---

### Pitfall 3: git-crypt Unlock Failure Leaves Encrypted Files Silently

**What goes wrong:** `git crypt unlock` can exit 0 while files remain encrypted. This happens when GPG prompts are suppressed (headless terminal, passphrase agent not running), or when the `.git/config` git-crypt state is shared but per-worktree unlock has not been run independently. The script proceeds with "unlocked" confidence while Claude Code reads binary garbage instead of secret files.

**Why it happens:** Each git worktree must be independently unlocked. git-crypt does not propagate the main worktree's unlock state to linked worktrees. The `git-crypt` lock state is per-worktree even though `.git/config` is shared. Issue [#105](https://github.com/AGWA/git-crypt/issues/105) and issue [#139](https://github.com/AGWA/git-crypt/issues/139) both confirm this behavior.

**Consequences:**
- Claude Code reads encrypted binary content, silently corrupts secrets into the state file or commits them
- Unlock "succeeds" with exit 0 but `git crypt status` shows files still encrypted
- If Claude commits encrypted content as plaintext, secrets are exposed in commit history

**Prevention:**
- After calling `git -C "$wt_path" crypt unlock "$key"`, immediately verify with `git -C "$wt_path" crypt status` and check exit code is 0. If not, abort with a clear error and remove the worktree.
- Follow the pattern in `gcom`'s `cmd_start` (lines 141-155): wrap unlock in a conditional that checks for key availability, and emit a visible warning when skipped rather than silently continuing.
- Never let Claude Code run if the unlock verification step fails. The state file must record `git_crypt_unlocked: true` only after verification, not after unlock command.

**Detection:**
- `git crypt status` shows "encrypted" files after unlock
- Secrets files contain lines starting with `\x00GITCRYPT`

**Phase mapping:** Phase 1 (worktree creation). Verification must be in the setup step before Claude is launched.

**Source:** [git-crypt issue #105](https://github.com/AGWA/git-crypt/issues/105), [git-crypt issue #139](https://github.com/AGWA/git-crypt/issues/139)

---

### Pitfall 4: gum Interactive Commands Exit Non-Zero and Kill the Script

**What goes wrong:** `writeShellApplication` enables `set -euo pipefail` automatically. `gum confirm` returns exit 1 when the user selects "No" and exit 130 when they press Ctrl+C. Under `set -e`, both of these non-zero exits immediately abort the script *with no cleanup*, leaving worktrees behind and state files half-written.

**Why it happens:** `gum confirm` is not a boolean-only tool; it has three distinct outcomes (yes/no/abort). Under strict mode, "no" and "abort" are indistinguishable from command failures. The entire worktree lifecycle depends on `gum confirm` for review and merge decisions, so this hits every interactive point in the flow.

**Consequences:**
- User clicks "No" on merge review, script aborts, worktree stays behind
- Ctrl+C during a review prompt leaves the worktree without the cleanup trap firing (if the trap was already deregistered)
- Partial state file writes if a gum prompt fires mid-sequence

**Prevention:**
- Never use bare `gum confirm` under strict mode. Always use the pattern:
  ```bash
  if gum confirm "Merge?"; then
    do_merge
  elif [[ $? -eq 130 ]]; then
    die "aborted by user"
  else
    info "skipping merge"
  fi
  ```
  The `if` construct captures the exit code before `set -e` can act on it.
- Alternatively, suffix every `gum` call with `|| true` if the "no" path is safe to continue from. Reserve explicit exit-code checks for cases where "no" should terminate.
- Register the cleanup trap with `trap cleanup EXIT` (not `ERR`) so it fires even on Ctrl+C (SIGINT sends exit 130, which triggers EXIT traps).

**Detection:**
- Script exits silently after a user interaction without printing a cleanup message
- Worktree remains after a "No" to merge confirmation

**Phase mapping:** Phase 2 (review/merge UI). All gum calls must be audited for this pattern before the interactive review phase is considered done.

**Source:** [gum exit codes discussion](https://github.com/charmbracelet/gum/discussions/263), [gum script exit handling](https://github.com/charmbracelet/gum/discussions/351)

---

### Pitfall 5: State File Corruption from Partial Writes

**What goes wrong:** The state file (`.worktree-state.json`) is written by piping `jq` output directly to the file path. If the script is interrupted mid-write (Ctrl+C, out-of-disk, process kill), the file is truncated. On resume, `jq` fails to parse the partial JSON, and the recovery path has no valid state to resume from.

**Why it happens:** Shell redirection (`jq ... > state.json`) is not atomic. The file descriptor is opened and truncated before jq writes a single byte. Any interruption leaves the file empty or with partial content.

**Consequences:**
- Recovery fails; the tool cannot determine what phase was reached
- The `RESUME` logic falls through to re-run already-completed steps (re-creating branches, re-pushing)
- State file becomes the single point of failure for the entire recovery system

**Prevention:**
- Always write state atomically using write-to-tempfile and rename:
  ```bash
  tmp="$(mktemp "$wt_path/.state.XXXXXX")"
  jq '...' > "$tmp" && mv "$tmp" "$wt_path/.worktree-state.json"
  ```
  `mv` on the same filesystem is atomic on Linux (single `rename(2)` syscall).
- After writing, immediately validate with `jq empty "$wt_path/.worktree-state.json"` to confirm parseable JSON.
- Keep the state file minimal: only store phase name, branch name, issue number, and flags. Never store large content (diff text, PR body) in the state file.

**Detection:**
- `jq: parse error` on resume
- State file is 0 bytes or ends mid-line

**Phase mapping:** Phase 1 setup (initial write) and every phase transition (update). Must be established before any recovery logic is built.

---

## Moderate Pitfalls

---

### Pitfall 6: Sibling Worktree Path Resolution Breaks When CWD Is Not the Main Repo

**What goes wrong:** The worktree location is computed as `$(git rev-parse --show-toplevel)/../.worktrees/issue-42/`. If the user invokes the tool from inside a nested subdirectory of the repo, `show-toplevel` still returns the correct repo root, so the path is safe. However, if the user is already *inside a different worktree*, `show-toplevel` returns that worktree's path, placing the new worktree one level up from it rather than one level up from the main repo. For repos with worktrees stored two levels deep, paths miscalculate.

**Why it happens:** `git rev-parse --show-toplevel` returns the working tree root, not the main repo root. In a linked worktree, those are different directories.

**Prevention:**
- Resolve the main repo root using `git worktree list --porcelain | awk 'NR==1{print $2}'` (first entry is always the main worktree) rather than `show-toplevel`.
- Validate that the computed path does not already exist before calling `git worktree add`.
- Print the resolved path prominently before creating the worktree.

**Detection:**
- New worktree appears at `../.worktrees/issue-42/../../.worktrees/` or similar unexpected path
- `git worktree list` shows unexpected depth

**Phase mapping:** Phase 1. The path resolution utility function must be tested from inside an existing worktree before the tool ships.

---

### Pitfall 7: gh CLI Pushes to Wrong Remote When Multiple Remotes Exist

**What goes wrong:** `gh pr create` resolves the "head" branch by looking at the current branch's tracking remote. In a worktree created from a fork (or a repo with both `origin` and `upstream` remotes), `gh` may silently push the feature branch to `upstream` instead of `origin`, creating the PR from the wrong source.

**Why it happens:** `gh pr create` issue [#588](https://github.com/cli/cli/issues/588) and [#5872](https://github.com/cli/cli/issues/5872) both document that `gh` defaults to the upstream remote when one is configured, not `origin`.

**Prevention:**
- Always call `git push -u origin "$branch"` explicitly *before* `gh pr create`, with `origin` hardcoded as the remote name.
- Pass `--head "origin:$branch"` to `gh pr create` to be explicit. Alternatively, pass `--repo owner/repo` to bypass remote inference entirely.
- Never rely on `gh` to push the branch; push first, then create PR.

**Detection:**
- PR is created but `git push` was not explicitly run beforehand
- `gh pr view` shows wrong fork as head

**Phase mapping:** Phase 2 (`github-issue` PR creation step).

**Source:** [gh pr create pushes to upstream](https://github.com/cli/cli/issues/588), [gh pr create defaults to wrong remote](https://github.com/cli/cli/issues/5872)

---

### Pitfall 8: Parallel Git Operations Racing on Shared Objects Database

**What goes wrong:** All worktrees share the same `.git/objects/` directory. Running `git fetch` in one worktree while another performs `git add` or `git commit` can create an `index.lock` collision. Claude Code itself performs background git operations (status checks, auto-staging) that can collide with the shell script's explicit git calls.

**Why it happens:** Git's index lock is per-worktree (each worktree has its own index file), but object database writes use file-level locking that can still race. Claude Code issue [#11005](https://github.com/anthropics/claude-code/issues/11005) specifically documents that Claude's background git operations leave stale `index.lock` files.

**Consequences:**
- `fatal: Unable to create '.git/index.lock': File exists` errors mid-script
- Fetch at session start races with Claude's initial workspace scan

**Prevention:**
- Add a 500ms delay between launching Claude and running any git operations in the same worktree.
- Wrap all git operations in a retry loop (max 3 attempts with 1s sleep) to handle transient lock collisions.
- Never run `git fetch` while Claude is actively running in the worktree. Do all fetching *before* launching Claude.

**Detection:**
- `index.lock` errors in log output
- Git commands fail intermittently but not consistently

**Phase mapping:** Phase 1 (all fetch/setup operations should complete before Claude is launched).

**Source:** [Claude Code stale index.lock issue](https://github.com/anthropics/claude-code/issues/11005), [git worktree parallel operations](https://devtoolbox.dedyn.io/blog/git-index-lock-file-exists-fix-guide)

---

### Pitfall 9: writeShellApplication Strict Mode Breaks Expected Non-Zero Patterns

**What goes wrong:** `pkgs.writeShellApplication` wraps the script with `set -o errexit -o nounset -o pipefail` (strict mode). Many common idioms used in the `gcom` codebase fail under these conditions:

- `grep -q pattern file || true` is fine, but bare `grep -q pattern file` aborts on no-match
- `git rev-parse --verify "$ref" 2>/dev/null` returns 1 when the ref does not exist -- this is a safe probe, but strict mode treats it as failure
- `ahead="$(git rev-list --count ... 2>/dev/null)" || ahead=0` is the correct pattern (seen in gcom), but only if the `|| ahead=0` fallback is actually present

**Prevention:**
- For every git command used as a conditional probe (not an operation), append `|| true` or use an `if` construct.
- Review every pipeline with `|` for commands that legitimately exit non-zero (grep, head, awk with no matches).
- Run shellcheck on the scripts in CI. `writeShellApplication` runs shellcheck automatically -- treat warnings as errors.
- Refer to the existing `gcom` script patterns as the reference implementation: note how `ahead` and `behind` are guarded with `|| 0` fallbacks (lines 219, 234).

**Detection:**
- Script exits silently with no error message at a probe/check command
- shellcheck warnings for `SC2181` (checking `$?` instead of condition)

**Phase mapping:** All phases. This is a cross-cutting concern; every new shell function must be audited.

**Source:** [writeShellApplication Nix docs](https://ryantm.github.io/nixpkgs/builders/trivial-builders/), [writeShellApplication unexpected behavior](https://discourse.nixos.org/t/writeshellapplication-not-running-bash-script-as-you-would-expect/18639)

---

## Minor Pitfalls

---

### Pitfall 10: Branch Name Collision When Issue Has Already Been Worked

**What goes wrong:** `fix/issue-42` already exists as a local branch from a previous interrupted run. `git worktree add ... -b fix/issue-42` fails with `fatal: A branch named 'fix/issue-42' already exists`. The script aborts, and the user sees a confusing error rather than a "resume this existing worktree?" prompt.

**Prevention:**
- Before calling `git worktree add`, check whether the branch already exists with `git show-ref --verify --quiet "refs/heads/$branch"`.
- If it exists and a state file is present at the expected worktree path, offer to resume rather than aborting. If it exists without a valid state file, prompt to delete and recreate.
- Follow the pattern in `gcom cmd_start` (line 125): explicit pre-check with a clear error message.

**Phase mapping:** Phase 1. This is the first guard in the setup function.

---

### Pitfall 11: Claude Code Session Leaves Behind .claude/ Artifacts in Worktree

**What goes wrong:** Claude Code writes session state, conversation history, and task files to `.claude/` relative to its working directory. In a worktree, this creates `.claude/` inside the worktree directory. If the worktree is force-removed without cleanup, these files may not be tracked by git and will not be pruned by `git worktree prune`.

**Prevention:**
- The cleanup function should delete `.claude/` from the worktree path before calling `git worktree remove`.
- If the worktree was placed at `../.worktrees/issue-42/` (outside the repo), use `rm -rf "$wt_path/.claude"` as a pre-step in cleanup.
- Consider passing `--no-session` or equivalent flags to claude if the session does not need persistence (for fully automated runs).

**Phase mapping:** Phase 3 (cleanup).

---

### Pitfall 12: Worktree on a Branch That main Has Diverged From

**What goes wrong:** If the feature branch was created from a stale `origin/main` and `origin/main` has since moved forward, `git merge --ff-only` in the `hack` local merge path will fail. The script needs to rebase before merging, but a rebase inside a worktree with uncommitted Claude changes risks losing work.

**Prevention:**
- In the `hack` review phase, run `git fetch origin main` and check `git rev-list --count HEAD..origin/main` before presenting the diff.
- If `origin/main` is ahead, automatically rebase the feature branch onto it *before* showing the diff review. Abort with a clear message if the rebase has conflicts.
- Never attempt `merge --ff-only` without first verifying zero commits behind.

**Phase mapping:** Phase 2 (`hack` merge review).

---

## Phase-Specific Warnings

| Phase Topic | Likely Pitfall | Mitigation |
|-------------|---------------|------------|
| Worktree creation | Orphaned worktree on mid-setup failure | `trap cleanup EXIT` registered immediately after `git worktree add` |
| git-crypt unlock | Silent failure, encrypted files passed to Claude | Verify with `git crypt status` after unlock, abort if files still encrypted |
| State file write | Partial JSON on interrupt | Write to tempfile, `mv` atomically, validate with `jq empty` |
| Claude launch | Index lock race with Claude background operations | Complete all git operations before launching Claude |
| gum interactive prompts | Strict mode exit on "No" answer | Use `if gum confirm` construct, never bare `gum confirm` |
| PR creation | Push to wrong remote | Always `git push -u origin` before `gh pr create`, pass `--head` explicitly |
| Local merge (hack) | ff-only fails if main diverged | Fetch and rebase check before presenting diff review |
| Cleanup | Branch stuck "checked out" | `git worktree remove` then `git worktree prune` then branch delete |
| Cleanup | User-deleted worktree dir leaves dangling branch ref | `prune` at start of every cleanup function |
| Cross-cutting | Strict mode aborts on probe commands | Every non-operational git command needs `|| true` or `if` guard |

---

## Sources

- [git-worktree official docs](https://git-scm.com/docs/git-worktree)
- [Worktree bootstrap orphan issue (opencode)](https://github.com/anomalyco/opencode/issues/14648)
- [Stale worktrees never cleaned up (Claude Code)](https://github.com/anthropics/claude-code/issues/26725)
- [Claude Code stale index.lock from background ops](https://github.com/anthropics/claude-code/issues/11005)
- [git-crypt worktree compatibility issue #105](https://github.com/AGWA/git-crypt/issues/105)
- [git-crypt unlock silent failure #139](https://github.com/AGWA/git-crypt/issues/139)
- [gum confirm exit codes discussion](https://github.com/charmbracelet/gum/discussions/263)
- [gum script exit handling](https://github.com/charmbracelet/gum/discussions/351)
- [gh pr create pushes to upstream remote](https://github.com/cli/cli/issues/588)
- [gh pr create defaults to upstream not origin](https://github.com/cli/cli/issues/5872)
- [writeShellApplication unexpected behavior (Discourse)](https://discourse.nixos.org/t/writeshellapplication-not-running-bash-script-as-you-would-expect/18639)
- [Trivial builders / writeShellApplication docs](https://ryantm.github.io/nixpkgs/builders/trivial-builders/)
- [Atomic JSON write pattern](https://dev.to/constanta/crash-safe-json-at-scale-atomic-writes-recovery-without-a-db-3aic)
- [git index.lock race conditions](https://devtoolbox.dedyn.io/blog/git-index-lock-file-exists-fix-guide)
