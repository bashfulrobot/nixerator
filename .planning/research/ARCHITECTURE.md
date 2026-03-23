# Architecture Patterns

**Project:** worktree-flow
**Researched:** 2026-03-11
**Confidence:** HIGH (derived from direct codebase analysis, no speculative claims)

---

## Recommended Architecture

Four distinct components with clear ownership boundaries:

```
modules/apps/cli/worktree-flow/
├── default.nix                  # Module: options + writeShellApplication wiring
├── scripts/
│   ├── lib.sh                   # Shared functions (sourced by both scripts)
│   ├── github-issue.sh          # Issue workflow script
│   └── hack.sh                  # Ad-hoc hack workflow script
└── SKILL.md                     # Simplified Claude instructions (implementation only)
```

The SKILL.md lives in the worktree-flow module, not in `claude-code/skills/`, because its
lifecycle is owned by this module. The github-issue skill in `claude-code/skills/` is
replaced or reduced to a pointer, or removed entirely once the shell script takes over.

---

## Component Boundaries

| Component              | Responsibility                                                                  | Inputs                          | Outputs                                 |
| ---------------------- | ------------------------------------------------------------------------------- | ------------------------------- | --------------------------------------- |
| `default.nix`          | Nix packaging; wires runtimeInputs; declares `apps.cli.worktree-flow.enable`    | lib, pkgs, config               | system packages: `github-issue`, `hack` |
| `lib.sh`               | Shared shell functions; sourced (not executed)                                  | sourced by both scripts         | functions in scope                      |
| `github-issue.sh`      | Issue worktree lifecycle: create, delegate to Claude, push, PR, cleanup         | issue number, flags             | worktree, state file, PR on GitHub      |
| `hack.sh`              | Ad-hoc worktree lifecycle: create, delegate to Claude, diff review, local merge | description, flags              | worktree, state file, merged commit     |
| `SKILL.md`             | Claude's implementation instructions only: commit format, PR body format        | read by Claude at session start | Claude behavior inside the worktree     |
| `.worktree-state.json` | Runtime state file written in worktree root; enables resume on interrupt        | written by shell scripts        | read by shell scripts on re-invocation  |

**What `lib.sh` owns (shared across both scripts):**

- Color/output helpers (`info`, `ok`, `warn`, `die`)
- `require_git_repo` guard
- `default_branch` detection (mirrors gcom pattern: symbolic-ref, then fallback to main)
- `repo_name` / `repo_root` helpers
- `slug_from_string` (lowercase, strip non-alnum, replace spaces with hyphens)
- `worktree_path` builder (constructs `../.worktrees/<prefix>-<id>`)
- `state_write` / `state_read` (jq-based reads/writes to `.worktree-state.json`)
- `launch_claude` (constructs and executes the `claude` invocation with SKILL.md context)
- `worktree_cleanup` (removes worktree dir and deletes local branch)

**What each script owns exclusively:**

- `github-issue.sh`: `gh issue view`, `gh pr create`, `gh issue comment`, phase detection logic
- `hack.sh`: gum diff review loop (`gum pager < diff`), local merge via `git merge --ff-only`, no GitHub interaction

---

## Data Flow

### github-issue flow

```
User: github-issue 42
        |
        v
[github-issue.sh]
  1. Parse args (issue number, --auto flag)
  2. Check .worktree-state.json (resume?) ──── if exists, load phase from state
  3. fetch issue via gh issue view
  4. derive branch name: fix/<slug> or feat/<slug>
  5. git worktree add ../.worktrees/issue-42/ -b fix/<slug> origin/main
  6. write .worktree-state.json (phase=implement, issue=42, branch=fix/<slug>)
        |
        v
[claude -p "..." --context SKILL.md]  (cwd = ../.worktrees/issue-42/)
  Claude reads SKILL.md for commit conventions and PR format
  Claude implements, commits (with -S), pushes via git push -u origin fix/<slug>
  Claude creates PR via gh pr create
  Claude writes result to stdout
        |
        v
[github-issue.sh resumes after claude exits]
  7. update .worktree-state.json (phase=awaiting-merge, pr_url=...)
  8. display PR URL to user via gum style
  9. ask: "Clean up worktree now or keep for follow-up?" (gum confirm)
  10. if confirmed: worktree_cleanup()
  11. on re-invocation after merge: post-merge comments, final cleanup
```

### hack flow

```
User: hack "add dark mode toggle"
        |
        v
[hack.sh]
  1. Parse args (description string)
  2. derive slug: hack/<slug>
  3. git worktree add ../.worktrees/hack-<slug>/ -b hack/<slug> origin/main
  4. write .worktree-state.json (phase=implement, description=...)
        |
        v
[claude -p "..." --context SKILL.md]  (cwd = ../.worktrees/hack-<slug>/)
  Claude implements and commits
        |
        v
[hack.sh resumes after claude exits]
  5. read .worktree-state.json (verify phase, branch)
  6. git diff main..hack/<slug> | gum pager   (diff review)
  7. gum confirm "Merge into main?"
  8. if confirmed:
       git -C <repo_root> merge --ff-only hack/<slug>
       worktree_cleanup()
  9. if rejected: warn, leave worktree in place, print path for manual inspection
```

### State file contract (.worktree-state.json)

Written by the shell script into the worktree root immediately after `git worktree add`.
Survives Claude context compression because it is a plain file on disk.

```json
{
  "tool": "github-issue",
  "version": 1,
  "phase": "implement",
  "issue": 42,
  "branch": "fix/some-slug",
  "worktree": "/home/user/dev/repo/../.worktrees/issue-42",
  "repo_root": "/home/user/dev/repo",
  "pr_url": null,
  "created_at": "2026-03-11T10:00:00Z"
}
```

Fields `phase` and `pr_url` are updated by the shell script as the workflow progresses.
Claude does not read or write this file. It is strictly shell-to-shell state.

---

## How the Shell Script Launches Claude

Both scripts launch Claude the same way, via a shared `launch_claude` function in `lib.sh`:

```bash
launch_claude() {
  local skill_md="$1"    # absolute path to SKILL.md
  local prompt="$2"      # the task description or issue context
  local worktree="$3"    # absolute path to worktree dir

  # Run claude headlessly (-p) inside the worktree directory
  # Pass the SKILL.md as context via --context or inline in the prompt
  # The worktree's cwd means all git ops land in the right place
  (
    cd "$worktree"
    claude -p "$prompt" --allowedTools "Bash,Read,Write,Edit,Grep,Glob"
  )
}
```

The SKILL.md content is embedded in the prompt string rather than passed as a file flag,
because `claude -p` accepts a full prompt. The shell script constructs:

```
"$(cat "$SKILL_MD")\n\n## Task\n\n$task_description"
```

This avoids filesystem path assumptions about where Claude resolves `--context` files.

The `--allowedTools` flag restricts Claude to implementation tools only. No `EnterPlanMode`,
no `AskUserQuestion`, no `Agent` spawning. The shell script owns the lifecycle; Claude owns
the implementation inside the worktree.

---

## How SKILL.md Communicates Back

SKILL.md does not communicate back via a structured protocol. Communication is:

1. **Commits**: Claude commits its work using `git commit -S`. The shell script reads
   `git log` after Claude exits to confirm work was done.
2. **Exit code**: `claude -p` exits 0 on success, non-zero on failure. Shell script checks
   `$?` and branches accordingly.
3. **Push**: For `github-issue`, Claude is instructed in SKILL.md to push and create the PR.
   The shell script reads the PR URL by calling `gh pr list --head <branch> --json url` after
   Claude exits rather than trusting Claude to print a parseable output.
4. **State file**: Claude does NOT write to `.worktree-state.json`. The shell script updates
   it based on observable git/gh state after Claude exits.

This keeps Claude's role purely implementation: no lifecycle awareness, no file-format
contracts, no structured output parsing.

---

## Nix Module Wiring

Pattern derived from `gcmt` (single-file scripts) and `gcom` (inline scripts). The preferred
pattern for this module uses external script files like `gcmt`:

```nix
# default.nix sketch
let
  cfg = config.apps.cli.worktree-flow;

  # Source lib.sh into each script at build time via string concatenation.
  # writeShellApplication prepends set -euo pipefail and PATH from runtimeInputs.
  libSh = builtins.readFile ./scripts/lib.sh;

  github-issue = pkgs.writeShellApplication {
    name = "github-issue";
    runtimeInputs = with pkgs; [ git gh gum jq coreutils gnused ];
    text = libSh + "\n" + builtins.readFile ./scripts/github-issue.sh;
  };

  hack = pkgs.writeShellApplication {
    name = "hack";
    runtimeInputs = with pkgs; [ git gum jq coreutils gnused ];
    text = libSh + "\n" + builtins.readFile ./scripts/hack.sh;
  };
in
{
  options.apps.cli.worktree-flow.enable = lib.mkOption { ... };
  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ github-issue hack ];
  };
}
```

The `libSh + "\n" + script` concatenation is the right approach because `writeShellApplication`
wraps the entire `text` in a single script. There is no `source` at runtime because the Nix
store paths are not predictable; inlining at build time is the correct pattern.

The SKILL.md is deployed by the claude-code module's skills installation mechanism (already
exists). A symlink or file copy is placed at `~/.claude/skills/github-issue/SKILL.md` by
the claude-code module. The worktree-flow module provides the file at build time; the
claude-code module's existing skills-copy mechanism deploys it. Alternatively, the
worktree-flow module can deploy it directly via `home.file`.

---

## Worktree Naming and Location

| Workflow                                      | Branch name                                    | Worktree path                                  |
| --------------------------------------------- | ---------------------------------------------- | ---------------------------------------------- |
| `github-issue 42`                             | `fix/<slug-from-issue-title>` or `feat/<slug>` | `<repo-parent>/.worktrees/issue-42/`           |
| `github-issue 42` (if issue title not usable) | `fix/issue-42`                                 | `<repo-parent>/.worktrees/issue-42/`           |
| `hack "add dark mode"`                        | `hack/add-dark-mode`                           | `<repo-parent>/.worktrees/hack-add-dark-mode/` |

The `<repo-parent>` is always `$(git rev-parse --show-toplevel)/..`. This puts worktrees
as siblings to the repo, not inside it, avoiding `.gitignore` complexity and nested-git
detection issues. This matches the gcom worktree pattern already in the codebase.

The `.worktrees/` directory is created with `mkdir -p` on first use. No Nix configuration
needed; it is a runtime artifact.

---

## Suggested Build Order

Dependencies flow upward. Build lower items first.

```
1. lib.sh           -- no dependencies; just shell functions
2. default.nix      -- depends on lib.sh existing to concatenate
3. github-issue.sh  -- depends on lib.sh functions being available
4. hack.sh          -- depends on lib.sh functions being available
5. SKILL.md         -- independent of scripts; can be written in parallel with step 1
6. Module wiring    -- default.nix fully connects everything
```

**Phase implications:**

- Phase 1 should deliver `lib.sh` + `default.nix` skeleton + `SKILL.md` (simplified).
  This establishes the Nix module compiles and the skill is deployed correctly.
- Phase 2 delivers `github-issue.sh` with the full lifecycle (create, launch, post-merge).
  Depends on Phase 1's lib functions.
- Phase 3 delivers `hack.sh` with gum diff review and local merge.
  Depends on Phase 1's lib functions. Largely parallel to Phase 2 but simpler (no GitHub).
- Phase 4 is integration: end-to-end testing of both flows, edge cases (interrupted sessions,
  existing worktree detection, re-invocation after merge).

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: Source lib.sh at runtime via path

**What:** Using `source /nix/store/.../lib.sh` or a relative `source ./lib.sh` at runtime.
**Why bad:** Nix store paths are not stable across generations. `writeShellApplication`
does not expose script paths as environment variables. The build-time concatenation
(`libSh + script`) is the correct Nix idiom.
**Instead:** Concatenate at build time in `default.nix`.

### Anti-Pattern 2: Claude writes the state file

**What:** SKILL.md instructs Claude to write `.worktree-state.json`.
**Why bad:** Introduces a fragile structured-output contract with the AI. If Claude's format
drifts or it skips the write, the shell script breaks silently.
**Instead:** Shell script writes and reads state. Claude only produces commits and git operations.

### Anti-Pattern 3: Inline scripts in default.nix (gcom style)

**What:** Putting the full `github-issue` and `hack` scripts inline in the Nix file.
**Why bad:** These scripts are long (150-300 lines each). Inline embedding loses syntax
highlighting, shellcheck linting, and editor support. The `gcmt` pattern (external files
via `builtins.readFile`) is cleaner for scripts of this size.
**Instead:** External files in `scripts/`, concatenated at build time.

### Anti-Pattern 4: Letting Claude manage the worktree lifecycle

**What:** SKILL.md contains `git worktree add`, branch creation, cleanup instructions.
**Why bad:** This is the current state that causes context drift and no isolation. The shell
script must own the worktree lifecycle entirely.
**Instead:** Shell creates, manages, and cleans up the worktree. SKILL.md only contains
commit conventions and PR body format.

### Anti-Pattern 5: Using `--auto` mode from existing SKILL.md

**What:** Carrying over the `--auto` mode distinction into the new skill.
**Why bad:** The new architecture eliminates the need: the shell script handles the lifecycle
deterministically. Claude always runs headlessly (`-p`) inside the worktree. There is no
interactive-vs-autonomous distinction because the human interaction happens in the terminal
via gum, not inside Claude's conversation loop.
**Instead:** Remove mode flags from SKILL.md. The new SKILL.md has no modes.

---

## Scalability Considerations

This is a local developer tool. Scalability concerns are about parallel terminal sessions,
not load.

| Concern                          | Handling                                                                                                             |
| -------------------------------- | -------------------------------------------------------------------------------------------------------------------- |
| Two terminals, same issue number | Worktree path collision: `git worktree add` fails if path exists. Script detects this and resumes from state file.   |
| Interrupted session              | State file persists in worktree. Re-invocation detects existing worktree, reads phase, resumes from last checkpoint. |
| Multiple repos simultaneously    | Worktree paths are scoped under each repo's parent directory. No cross-repo collisions.                              |
| Very long slug names             | `slug_from_string` truncates to 40 chars to keep branch names under git's practical limit.                           |

---

## Sources

- Direct codebase analysis: `modules/apps/cli/gcmt/default.nix` (writeShellApplication pattern)
- Direct codebase analysis: `modules/apps/cli/gcmt/scripts/gcmt.sh` (gum UI pattern)
- Direct codebase analysis: `modules/apps/cli/git/default.nix` (gcom worktree patterns, shared helper functions, `git -C` cross-directory operations)
- Direct codebase analysis: `modules/apps/cli/claude-code/skills/github-issue/SKILL.md` (current skill to be simplified)
- Direct codebase analysis: `.planning/PROJECT.md` (constraints, decisions, worktree location spec)
- Codebase convention: `modules/CLAUDE.md` (module namespace, HM config placement, enable option pattern)
