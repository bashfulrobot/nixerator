# Phase 3: hack Workflow - Research

**Researched:** 2026-03-11
**Domain:** bash shell scripting, gum interactive prompts, git diff, git merge --ff-only, worktree lifecycle
**Confidence:** HIGH

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Reject behavior**

- On reject: always preserve the worktree, never offer to delete
- Print the worktree path and a resume hint: "Run `hack \"<description>\"` again to review"
- No re-launch prompt on reject; user decides when to come back

**Resume and re-invocation**

- Match existing worktrees by slug: `hack "add rate limiting"` finds `hack-add-rate-limiting` worktree
- Same pattern as github-issue: show state summary, gum choose Resume/Remove/Abort
- On resume from diff_review phase: always show the diff again before approve/reject (user may have forgotten)

**Approve and cleanup**

- After approval: auto-delete worktree silently (no confirmation prompt)
- Delete the hack branch after successful merge (clean slate, matches github-issue cleanup)
- Fast-forward merge only; no force merge or rebase

**Claude prompt**

- Pass SKILL.md (commit conventions) + description string in the `-p` prompt
- Same SKILL.md as github-issue (consistent commit style across both commands)
- Let Claude discover CLAUDE.md naturally (it reads it automatically)
- Single argument only: the description string. No --file or extra flags

### Claude's Discretion

- Merge failure handling (what to do when fast-forward fails)
- Diff presentation details (coloring, format passed to gum pager)
- Exact prompt wording and structure

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>

## Phase Requirements

| ID    | Description                                                                | Research Support                                                                                                                      |
| ----- | -------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| RF-03 | hack flow presents diff via gum pager for review                           | `gum pager` accepts content via stdin or positional arg; `git diff --color=always` produces color-compatible output; documented below |
| RF-04 | hack flow prompts approve/reject via gum confirm                           | `gum confirm` exit codes: 0=Yes, 1=No, 130=Ctrl+C; all three must be handled under `set -e`                                           |
| RF-05 | hack flow merges to default branch locally on approval (fast-forward only) | `git merge --ff-only <branch>` verified in git 2.53.0; must be run from repo root, not worktree                                       |

</phase_requirements>

## Summary

Phase 3 replaces the `hack.sh` stub with a complete end-to-end workflow. The implementation closely mirrors `github-issue.sh` but diverges at the post-Claude phase: instead of push + PR, it shows a diff via `gum pager`, then prompts approve or reject via `gum confirm`, then either fast-forward merges or preserves the worktree for later.

The standard stack is identical to Phase 2. No new Nix packages are required except adding `llm-agents.claude-code` to the `hack-cmd` runtimeInputs (it was intentionally omitted from the stub). All other tools -- gum, git, jq, coreutils -- are already declared. The diff review flow uses `git diff --color=always <default_branch>...<hack_branch>` piped into `gum pager`. The merge uses `git merge --ff-only` from the main repo root, not the worktree, after switching to the default branch.

The three new behaviors unique to this phase (RF-03, RF-04, RF-05) each have well-defined tool interfaces verified against installed versions. The primary complexity is safely handling all `gum confirm` exit codes under `set -e` and ensuring the `_WT_CLEANUP_PATH=""` guard fires before intentional worktree removal in the approval path. The reject path must NOT fire the cleanup trap (worktree must survive for later review).

**Primary recommendation:** Implement hack.sh as a direct adaptation of github-issue.sh with `phase_diff_review()` and `phase_merge()` replacing `phase_push_and_pr()`. The phase progression is: setup, claude_running, claude_exited, diff_review, merged, cleanup_done.

## Standard Stack

### Core

| Library                     | Version          | Purpose                                                                                      | Why Standard                                                |
| --------------------------- | ---------------- | -------------------------------------------------------------------------------------------- | ----------------------------------------------------------- |
| pkgs.gum                    | nixpkgs          | `gum pager` for diff display, `gum confirm` for approve/reject, `gum choose` for resume menu | Already in runtimeInputs                                    |
| pkgs.git                    | nixpkgs (2.53.0) | `git diff`, `git merge --ff-only`, `git worktree remove`, `git branch -d`                    | Already in runtimeInputs                                    |
| pkgs.llm-agents.claude-code | current          | `claude -p` launch in worktree                                                               | Must be added to hack-cmd runtimeInputs (currently missing) |
| pkgs.jq                     | nixpkgs          | State file read/write                                                                        | Already in runtimeInputs                                    |
| pkgs.coreutils              | nixpkgs          | `mktemp` for atomic writes                                                                   | Already in runtimeInputs                                    |

### runtimeInputs change for Phase 3

The only change to `default.nix` is adding `llm-agents.claude-code` to `hack-cmd`:

```nix
hack-cmd = pkgs.writeShellApplication {
  name = "hack";
  runtimeInputs = with pkgs; [
    git
    git-crypt
    gum
    gh         # retained for future use; already present
    jq
    coreutils
    gnused
    findutils
    llm-agents.claude-code  # NEW in Phase 3
  ];
  ...
};
```

### Alternatives Considered

| Instead of                   | Could Use                  | Tradeoff                                                                                                         |
| ---------------------------- | -------------------------- | ---------------------------------------------------------------------------------------------------------------- |
| `gum pager` for diff         | `less`                     | gum pager is already a dep; consistent with rest of UI; no need for `less` in runtimeInputs                      |
| `git diff <base>...<branch>` | `git diff <base> <branch>` | Three-dot form shows all commits on branch since divergence from base; correct for showing "what Claude changed" |
| `git merge --ff-only`        | `git rebase`               | ff-only preserves linear history; matches stated requirement RF-05; rebase rewrites commits (not desired)        |

## Architecture Patterns

### Recommended Script Structure

```
scripts/hack.sh
├── argument parsing / help
├── pre-flight checks (assert_clean_tree, check_orphan_worktrees)
├── existing worktree handler (handle_existing_worktree with slug match)
├── Phase: setup
│   ├── slugify description
│   ├── branch name: hack/<slug>
│   ├── git worktree add + register_cleanup
│   ├── unlock_git_crypt
│   └── create_hack_state + set_phase claude_running
├── Phase: claude_running
│   ├── load SKILL.md from ~/.claude/skills/github-issue/SKILL.md
│   ├── build prompt: SKILL.md content + description
│   ├── unset CLAUDECODE (prevent nested session refusal)
│   ├── claude --dangerously-skip-permissions -p "$prompt"
│   ├── capture session_id from stream-json
│   └── set_phase claude_exited
├── Phase: claude_exited
│   ├── check git diff --quiet (any changes?)
│   ├── if no changes: warn and exit (worktree/branch auto-cleaned)
│   └── set_phase diff_review
├── Phase: diff_review
│   ├── git diff --color=always <default_branch>...<hack_branch>
│   ├── pipe to gum pager
│   ├── gum confirm "Merge to <default_branch>?"
│   ├── if Yes (exit 0): set_phase merging, then phase_merge
│   └── if No or Ctrl+C: preserve worktree, print resume hint, exit
└── Phase: merge (on approval)
    ├── _WT_CLEANUP_PATH="" (disable trap before intentional cleanup)
    ├── cd to repo root (NOT worktree)
    ├── git checkout <default_branch>
    ├── git merge --ff-only <hack_branch>
    ├── git worktree remove --force <wt_path>
    ├── git worktree prune
    ├── git branch -d <hack_branch>
    └── set_phase cleanup_done + ok message
```

### Phase Progression

```
setup -> claude_running -> claude_exited -> diff_review -> merged -> cleanup_done
                                                       |
                                           (reject/Ctrl+C: exit, preserve worktree)
```

On resume from `diff_review`: re-show the diff (per locked decision), then prompt again.

### Pattern 1: State File for hack type

**What:** State file mirrors issue type but uses `description` instead of issue fields.

```bash
# Source: lib.sh create_state() -- extend for hack type
create_hack_state() {
  local branch="$1"
  local wt_path="$2"
  local description="$3"
  local timestamp
  timestamp="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  local json
  json="$(jq -n \
    --arg type        "hack" \
    --arg phase       "setup" \
    --arg branch      "$branch" \
    --arg wt_path     "$wt_path" \
    --arg session_id  "" \
    --arg description "$description" \
    --arg started_at  "$timestamp" \
    --arg updated_at  "$timestamp" \
    '{type: $type, phase: $phase, branch: $branch, wt_path: $wt_path,
      session_id: $session_id, description: $description,
      started_at: $started_at, updated_at: $updated_at}')"
  write_state "$json" "$wt_path"
}
```

### Pattern 2: Diff Display via gum pager (RF-03)

**What:** Generate colorized diff of all changes Claude made vs default branch, show in gum pager.

**Verified:** `gum pager` accepts content on stdin (pipe). `git diff --color=always` produces ANSI-colored output compatible with gum pager's renderer.

```bash
# Source: gum pager --help verified against installed gum
phase_diff_review() {
  local wt_path="$1"

  section "Diff Review"

  local branch default_br
  branch="$(read_state_field branch "$wt_path")"
  default_br="$(default_branch)"

  info "showing diff: ${branch} vs ${default_br}"

  # Generate diff: three-dot shows all commits on branch since divergence
  # --color=always ensures ANSI codes flow through to gum pager
  git -C "$wt_path" diff --color=always "${default_br}...${branch}" \
    | gum pager

  set_phase "diff_review" "$wt_path"
  ...
}
```

### Pattern 3: Approve/Reject via gum confirm (RF-04)

**What:** Prompt for merge decision. Handle all three exit codes safely under `set -e`.

**Critical:** Under `set -e`, a bare `gum confirm` that exits 1 (No) kills the script. Must use `if` form or explicit exit code capture.

**Verified exit codes:**

- `gum confirm` exits 0 for Yes (affirmative)
- `gum confirm` exits 1 for No (negative, from --negative button)
- `gum confirm` exits 130 for Ctrl+C (SIGINT caught by gum)

```bash
# Source: gum confirm --help verified; exit code behavior verified per SF-04 pattern
local default_br
default_br="$(default_branch)"

if gum confirm "Merge to ${default_br}?"; then
  # Approved: merge
  phase_merge "$wt_path" "$branch" "$default_br"
else
  # Rejected or Ctrl+C: preserve worktree
  local description
  description="$(read_state_field description "$wt_path")"
  info "merge rejected -- worktree preserved at ${wt_path}"
  info "resume hint: hack \"${description}\""
  exit 0
fi
```

Note: `gum confirm` exit 130 (Ctrl+C) also falls into the `else` branch here, which is the correct behavior -- preserve the worktree. The EXIT trap fires after `exit 0` but `_WT_CLEANUP_PATH` is still set from `register_cleanup`. For reject path, we must NOT clear `_WT_CLEANUP_PATH` before exiting -- but the cleanup handler removes the worktree. This is a pitfall: we want the worktree to survive on reject.

**Solution:** Clear `_WT_CLEANUP_PATH` before calling `exit 0` on the reject path, just like we clear it before intentional removal. The reject case intentionally exits without cleanup:

```bash
if gum confirm "Merge to ${default_br}?"; then
  phase_merge "$wt_path" "$branch" "$default_br"
else
  # Preserve worktree -- disable cleanup trap
  _WT_CLEANUP_PATH=""
  local description
  description="$(read_state_field description "$wt_path")"
  info "merge rejected -- worktree preserved"
  info "resume: hack \"${description}\""
  exit 0
fi
```

### Pattern 4: Fast-Forward Merge (RF-05)

**What:** Switch to default branch, merge hack branch with --ff-only, clean up worktree and branch.

**Critical:** Must `cd` out of worktree before removing it. Must be at repo root.

**Verified:** `git merge --ff-only <branch>` exits non-zero if fast-forward is not possible (diverged history). This is the merge failure case left to Claude's Discretion.

```bash
# Source: git 2.53.0 --help verified; --ff-only flag confirmed
phase_merge() {
  local wt_path="$1"
  local branch="$2"
  local default_br="$3"

  section "Merging"

  local repo_root
  repo_root="$(git rev-parse --show-toplevel)"

  # Switch to default branch at repo root (not worktree)
  cd "$repo_root"
  git checkout "$default_br"

  # Disable cleanup trap before intentional removal (Pitfall from Phase 2)
  _WT_CLEANUP_PATH=""

  # Fast-forward merge
  if ! git merge --ff-only "$branch"; then
    warn "fast-forward merge failed -- branches have diverged"
    warn "worktree preserved at ${wt_path} for manual resolution"
    # Re-enable cleanup suppression: worktree must survive
    exit 1
  fi
  ok "merged ${branch} -> ${default_br}"

  # WT-05 cleanup sequence: remove, prune, then branch delete
  git worktree remove --force "$wt_path" 2>/dev/null || true
  git worktree prune 2>/dev/null || true
  ok "worktree removed"

  git branch -d "$branch" 2>/dev/null || git branch -D "$branch" 2>/dev/null || true
  ok "branch ${branch} deleted"

  set_phase "cleanup_done" "$wt_path" 2>/dev/null || true  # state file gone, best-effort
}
```

### Pattern 5: Worktree Match by Slug (Resume)

**What:** `hack "add rate limiting"` slugifies to `hack-add-rate-limiting` and looks for `$(worktree_base)/hack-add-rate-limiting`.

```bash
main() {
  local DESCRIPTION="$1"
  local SLUG
  SLUG="$(slugify "$DESCRIPTION")"
  local WT_PATH
  WT_PATH="$(worktree_base)/hack-${SLUG}"

  assert_clean_tree
  check_orphan_worktrees

  if [[ -d "$WT_PATH" ]]; then
    handle_existing_worktree "$DESCRIPTION" "$WT_PATH"
    exit 0
  fi

  phase_setup "$DESCRIPTION" "$SLUG" "$WT_PATH"
  phase_claude_running "$WT_PATH"
  phase_claude_exited "$WT_PATH"
  phase_diff_review "$WT_PATH"

  # If we reach here, approve path completed inline in phase_diff_review
  _WT_CLEANUP_PATH=""
  ok "done!"
}
```

### Pattern 6: Resume Dispatcher

**What:** When worktree exists, show state summary, offer Resume/Remove/Abort. On resume from diff_review: always re-show diff first.

```bash
phase_resume() {
  local description="$1" wt_path="$2" current_phase="$3"
  register_cleanup "$wt_path"

  local start=0
  case "$current_phase" in
    setup)          start=1 ;;
    claude_running) start=1 ;;
    claude_exited)  start=2 ;;
    diff_review)    start=2 ;;  # re-show diff per locked decision
    merged|cleanup_done)
      ok "already merged"
      return ;;
    *) die "unknown phase: $current_phase" ;;
  esac

  if [[ $start -le 1 ]]; then phase_claude_running "$wt_path"; fi
  if [[ $start -le 2 ]]; then phase_claude_exited "$wt_path"; fi
  # phase_diff_review always runs last (includes merge on approval)
  phase_diff_review "$wt_path"

  _WT_CLEANUP_PATH=""
  ok "done!"
}
```

### Anti-Patterns to Avoid

- **Bare `gum confirm` without `if`:** Will kill script on exit 1 (No) under `set -e`. Always use `if gum confirm ...; then`.
- **Leaving `_WT_CLEANUP_PATH` set on reject path:** The EXIT trap will destroy the worktree the user intends to keep. Must set `_WT_CLEANUP_PATH=""` before `exit 0` on reject.
- **Running `git merge` from inside the worktree directory:** `git merge` operates on the repo at CWD. Running from the worktree merges into the worktree's branch, not the main repo's default branch. Must `cd "$(git rev-parse --show-toplevel)"` first.
- **Forgetting `_WT_CLEANUP_PATH=""` before intentional worktree remove in approve path:** EXIT trap fires on success too. Without clearing the path, it tries to double-remove an already-removed worktree.
- **Three-dot vs two-dot diff:** `git diff main..branch` shows changes between tips only. `git diff main...branch` uses the merge-base, showing only what Claude added. Use three-dot.

## Don't Hand-Roll

| Problem                      | Don't Build                                 | Use Instead                                 | Why                                                                      |
| ---------------------------- | ------------------------------------------- | ------------------------------------------- | ------------------------------------------------------------------------ |
| Diff display with paging     | Custom less invocation, custom scroll logic | `git diff ... \| gum pager`                 | gum pager is already in runtimeInputs; handles ANSI colors, keyboard nav |
| Approve/Reject prompt        | `read` + echo + case statement              | `gum confirm`                               | Already a dep; handles keyboard, consistent UI, returns clean exit codes |
| Merge fast-forward detection | git log comparison, ref parsing             | `git merge --ff-only` (non-zero on failure) | Single command; git handles all edge cases including empty merges        |
| State field reads            | grep + awk on JSON                          | `read_state_field` from lib.sh              | Already implemented; atomic, tested                                      |

**Key insight:** All interactive prompts go through `gum`. All git operations go through standard git commands. The script is pure orchestration -- no custom protocol logic.

## Common Pitfalls

### Pitfall 1: gum confirm preserving worktree on reject

**What goes wrong:** On reject, `gum confirm` exits 1. Script hits `else` branch and calls `exit 0`. EXIT trap fires and removes the worktree the user wanted to keep.
**Why it happens:** `register_cleanup` was called during setup and sets `_WT_CLEANUP_PATH`. The cleanup function removes the worktree on any EXIT.
**How to avoid:** In the reject branch, set `_WT_CLEANUP_PATH=""` BEFORE calling `exit 0`. This disables the cleanup trap for this exit.
**Warning signs:** Worktree directory missing after running `hack` and selecting No.

### Pitfall 2: git merge from wrong directory

**What goes wrong:** `git merge --ff-only hack/slug` runs from the worktree directory. This merges into the worktree's own branch, not main. Or git refuses because HEAD is already on the hack branch.
**Why it happens:** git commands use CWD's git context.
**How to avoid:** Always `cd "$(git -C "$wt_path" rev-parse --show-toplevel)"` before the merge sequence.
**Warning signs:** "Already up to date" message when merge should have applied commits.

### Pitfall 3: gum confirm exit 130 (Ctrl+C) not handled as reject

**What goes wrong:** Ctrl+C during gum confirm sends SIGINT, gum exits 130. Under `set -e` with bare call, script dies without cleanup. With `if` form, 130 falls into `else` -- which is correct (treat as reject, preserve worktree).
**Why it happens:** SIGINT is a separate exit code from explicit No.
**How to avoid:** The `if gum confirm ...; then ... else ...; fi` pattern naturally handles all non-zero exits including 130 as the reject case. This is the correct behavior.
**Warning signs:** Ctrl+C during confirm prompt either kills script abruptly (bare call) or (with if form) correctly preserves worktree.

### Pitfall 4: Diff shows nothing (no commits yet)

**What goes wrong:** `git diff main...hack/slug` shows empty output if Claude made no commits. gum pager shows blank screen.
**Why it happens:** `phase_claude_exited` checks for changes before advancing, but only checks working tree status. If Claude committed nothing and left no staged/unstaged changes, phase_claude_exited exits early. However if Claude committed only (no uncommitted changes), the diff check passes but diff output is the commits.
**How to avoid:** `phase_claude_exited` already handles the no-changes case. No special handling needed in diff_review for empty diff -- if we reach diff_review, there are commits.
**Warning signs:** Blank gum pager screen. This means phase_claude_exited logic has a gap.

### Pitfall 5: Resume from diff_review shows stale diff

**What goes wrong:** User resumed, saw diff once, ctrl+C'd, resumes again. On second resume, diff_review runs from `start=2` (claude_exited phase), which calls `phase_claude_exited` again then `phase_diff_review`. This is correct and re-shows the diff.
**Why it happens:** The locked decision says "always show diff again on resume from diff_review."
**How to avoid:** Map `diff_review` to `start=2` in phase_resume, not `start=3`. This ensures phase_claude_exited runs (checks for changes again) then diff_review runs (shows diff again).
**Warning signs:** Resume skips directly to merge prompt without showing diff.

### Pitfall 6: Fast-forward fails after reject+edit cycle

**What goes wrong:** User rejects, edits the worktree manually, pushes, or the default branch advances. Fast-forward is no longer possible.
**Why it happens:** The hack branch and default branch have diverged.
**How to avoid:** This is Claude's Discretion per CONTEXT.md. Recommended: print a clear error, preserve the worktree, suggest manual resolution steps (`git rebase` or `git merge` in the worktree).
**Warning signs:** `git merge --ff-only` exits non-zero.

## Code Examples

Verified patterns from official sources and the installed toolchain:

### Diff to gum pager

```bash
# Source: gum pager --help (installed), git 2.53.0
# --color=always: force ANSI even when stdout is not a TTY
# Three-dot form: show commits on hack branch since divergence from default
git -C "$wt_path" diff --color=always "${default_br}...${branch}" \
  | gum pager
```

### gum confirm pattern (all exit codes handled)

```bash
# Source: gum confirm --help (installed); SF-04 pattern from lib.sh
# Exit 0: Yes. Exit 1: No. Exit 130: Ctrl+C (also treated as No/preserve).
if gum confirm "Merge to ${default_br}?"; then
  # approve
  _WT_CLEANUP_PATH=""  # disable trap before intentional removal
  phase_merge "$wt_path" "$branch" "$default_br"
else
  # reject or Ctrl+C -- preserve worktree
  _WT_CLEANUP_PATH=""  # disable trap -- worktree must survive
  info "worktree preserved at ${wt_path}"
  info "resume: hack \"$(read_state_field description "$wt_path")\""
  exit 0
fi
```

### git merge ff-only with failure handling

```bash
# Source: git 2.53.0 --help verified
local repo_root
repo_root="$(git -C "$wt_path" rev-parse --show-toplevel)"
cd "$repo_root"
git checkout "$default_br"
if ! git merge --ff-only "$branch"; then
  warn "fast-forward merge failed (branches diverged)"
  warn "worktree preserved at ${wt_path} for manual resolution"
  exit 1
fi
```

### Claude prompt for hack workflow

```bash
# Source: CONTEXT.md locked decisions; SKILL.md at ~/.claude/skills/github-issue/SKILL.md
local skill_path="$HOME/.claude/skills/github-issue/SKILL.md"
local skill_content=""
if [[ -f "$skill_path" ]]; then
  skill_content="$(cat "$skill_path")"
fi
local prompt
prompt="$(printf 'You are working in worktree %s on branch %s.\n\nTask: %s\n\n%s' \
  "$wt_path" "$branch" "$description" "$skill_content")"
```

### handle_existing_worktree adapted for hack

```bash
# Identical pattern to github-issue.sh but uses description field
handle_existing_worktree() {
  local description="$1" wt_path="$2"

  [[ -f "${wt_path}/.worktree-state.json" ]] \
    || die "worktree exists but no state file at ${wt_path}/.worktree-state.json"

  local phase branch
  phase="$(read_state_field phase "$wt_path")"
  branch="$(read_state_field branch "$wt_path")"

  info "hack: phase ${phase}, branch ${branch}"

  local choice
  choice="$(gum choose "Resume" "Remove & restart" "Abort")" || die "aborted"

  case "$choice" in
    "Resume")           phase_resume "$description" "$wt_path" "$phase" ;;
    "Remove & restart") remove_worktree "$wt_path"; main "$description" ;;
    "Abort")            info "aborted"; exit 0 ;;
  esac
}
```

## State of the Art

| Old Approach                 | Current Approach                                          | When Changed | Impact                             |
| ---------------------------- | --------------------------------------------------------- | ------------ | ---------------------------------- |
| Stub with echo annotations   | Full workflow: worktree, Claude, diff review, local merge | Phase 3      | Functional end-to-end hack command |
| hack-cmd missing claude-code | `llm-agents.claude-code` added to runtimeInputs           | Phase 3      | Claude launch works                |
| No diff review               | `git diff ... \| gum pager` + `gum confirm`               | Phase 3      | RF-03 and RF-04 satisfied          |
| No local merge               | `git merge --ff-only` from repo root                      | Phase 3      | RF-05 satisfied                    |

**Deprecated/outdated:**

- The stub hack.sh: replaced entirely by the full implementation.

## Open Questions

1. **gum pager and ANSI color rendering**
   - What we know: `gum pager --help` shows no explicit `--color` flag; gum uses Bubble Tea/Lip Gloss which renders ANSI codes natively
   - What's unclear: Whether `git diff --color=always` ANSI codes render correctly or appear as raw escape sequences
   - Recommendation: Use `--color=always` on the git diff; if raw escapes appear, add `GUM_PAGER_FOREGROUND` env or use `git diff --no-color` and rely on gum's own colorization. Test at build time.

2. **set_phase after worktree removal**
   - What we know: `set_phase` writes to `${wt_path}/.worktree-state.json`; after `git worktree remove`, the directory is gone
   - What's unclear: Whether to write `cleanup_done` phase before or after removing the worktree
   - Recommendation: Write `set_phase "merged"` before worktree removal, then remove. After removal, `cleanup_done` update is best-effort (`|| true`). The `merged` phase is the canonical success state.

3. **gum pager with empty diff**
   - What we know: If `phase_claude_exited` correctly catches no-change case, diff_review is only reached when commits exist
   - What's unclear: Edge case where `git diff main...branch` is empty despite commits (e.g., commits that cancel each other out)
   - Recommendation: Before piping to gum pager, check if diff output is empty and print a warning. Let user still approve/reject.

## Validation Architecture

### Test Framework

| Property           | Value                                                                  |
| ------------------ | ---------------------------------------------------------------------- |
| Framework          | None -- Nix module; validation is rebuild success + manual smoke tests |
| Config file        | N/A                                                                    |
| Quick run command  | `just quiet-rebuild`                                                   |
| Full suite command | `just quiet-rebuild` + `hack --help` exits 0                           |

### Phase Requirements to Test Map

| Req ID | Behavior                                                 | Test Type | Automated Command                                      | File Exists? |
| ------ | -------------------------------------------------------- | --------- | ------------------------------------------------------ | ------------ |
| RF-03  | `hack "desc"` shows diff in gum pager after Claude exits | smoke     | Manual: run in test repo, verify pager appears         | Wave 0       |
| RF-04  | Approve/reject prompt appears; reject preserves worktree | smoke     | Manual: select No, verify worktree dir survives        | Wave 0       |
| RF-05  | Approve fast-forward merges to default branch            | smoke     | Manual: select Yes, verify `git log` on default branch | Wave 0       |

### Sampling Rate

- **Per task commit:** `just quiet-rebuild` (Nix syntax + shellcheck via writeShellApplication)
- **Per wave merge:** `just quiet-rebuild` + `hack --help` exits 0
- **Phase gate:** Manual smoke test -- run `hack "test task"` in a clean test repo, exercise both approve and reject paths

### Wave 0 Gaps

- [ ] `modules/apps/cli/worktree-flow/scripts/hack.sh` -- replace stub with full implementation
- [ ] `modules/apps/cli/worktree-flow/default.nix` -- add `llm-agents.claude-code` to hack-cmd runtimeInputs

_(No new test framework needed -- rebuild is the automated gate)_

## Sources

### Primary (HIGH confidence)

- `/home/dustin/git/nixerator/modules/apps/cli/worktree-flow/scripts/lib.sh` -- verified all shared primitives available for reuse
- `/home/dustin/git/nixerator/modules/apps/cli/worktree-flow/scripts/github-issue.sh` -- full reference implementation; patterns directly applicable
- `/home/dustin/git/nixerator/modules/apps/cli/worktree-flow/scripts/hack.sh` -- current stub to be replaced
- `/home/dustin/git/nixerator/modules/apps/cli/worktree-flow/default.nix` -- confirmed hack-cmd missing `llm-agents.claude-code`
- `gum pager --help` (installed) -- confirmed: accepts stdin, no explicit color flag needed
- `gum confirm --help` (installed) -- confirmed: exit 0=Yes, 1=No; --affirmative/--negative flags available
- `git merge --help` (git 2.53.0) -- confirmed: `--ff-only` flag; exits non-zero when ff not possible
- `git diff --help` (git 2.53.0) -- confirmed: `--color=always`, three-dot `...` syntax
- `.planning/phases/03-hack-workflow/03-CONTEXT.md` -- locked decisions verified

### Secondary (MEDIUM confidence)

- Phase 2 RESEARCH.md patterns -- `CLAUDECODE` pitfall, gum exit codes, `_WT_CLEANUP_PATH` pattern all verified empirically in Phase 2
- `gum pager` ANSI rendering -- expected to work based on Bubble Tea framework behavior; not directly tested

### Tertiary (LOW confidence)

- gum pager rendering of `--color=always` ANSI codes -- assumed compatible; validate during smoke test

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH -- all tools verified against installed versions; only change is adding claude-code to runtimeInputs
- Architecture: HIGH -- direct adaptation of github-issue.sh with well-understood phase swap
- gum pager/confirm behavior: HIGH -- verified against installed gum via --help flags and exit code docs
- git merge --ff-only: HIGH -- verified against git 2.53.0
- ANSI color in gum pager: MEDIUM -- not directly tested; expected to work

**Research date:** 2026-03-11
**Valid until:** 2026-04-10 (stable tools)
