# Phase 1: Foundation - Context

**Gathered:** 2026-03-11
**Status:** Ready for planning

<domain>
## Phase Boundary

Nix module scaffold at `modules/apps/cli/worktree-flow/`, lib.sh with all shared functions and safety primitives, and the Claude integration contract. Both `github-issue` and `hack` compile as stub commands in PATH. All shared primitives (state file I/O, worktree lifecycle, git-crypt, trap handlers, gum safety) are ready for Phases 2 and 3 to build on.

</domain>

<decisions>
## Implementation Decisions

### Claude Launch Contract

- Launch with `claude --dangerously-skip-permissions` (worktree IS the sandbox)
- Prompt passed inline via `-p` with SKILL.md content, issue body, and repo context concatenated into a single prompt string
- Output format: `--output-format stream-json` for structured output parsing
- Session ID captured from stream-json output and written to state file for `--resume` on re-invocation
- On Claude exit: continue regardless of exit code (`|| true`), check for actual changes via `git diff --quiet HEAD`, proceed to post-Claude phase if changes exist
- Claude's output streams visible to user in real-time (tee to terminal and state parsing)

### State File Design

- Linear phase tracking: setup, claude_running, claude_exited, pushing, pr_created (issue) / diff_review (hack), merged, cleanup_done
- Shared schema with `type` field ("issue" or "hack"); common fields shared, type-specific fields optional (pr_url for issue, description for hack)
- File lives at worktree root: `${WT_PATH}/.worktree-state.json`
- Filename: `.worktree-state.json` (dotfile, hidden from casual ls)
- Atomic writes: tmpfile + mv pattern (from WT-04 requirement)
- Schema includes: type, phase, issue/description, branch, worktree path, session_id, started_at, updated_at

### SKILL.md Placement

- Deployed via worktree-flow module's `home.file`, not claude-code module (self-contained, no cross-module dependency)
- Deploys to `~/.claude/skills/github-issue/SKILL.md`
- Remove old SKILL.md from `modules/apps/cli/claude-code/skills/github-issue/` (worktree-flow owns it now)
- SKILL.md scope: commit conventions (type(scope): emoji, -S signing, no Co-Authored-By) AND PR body format (Summary/Test plan)

### Terminal Output Style

- Reuse gcmt's color helper pattern: info/ok/warn/die with CYAN/GREEN/YELLOW/RED ANSI colors, defined in lib.sh
- Phase transitions announced with styled section headers via gum style (e.g., "-- Setting up worktree --")
- git-crypt auto-unlock: find first key in ~/.ssh/git-crypt/ automatically, single info() line, no interactive picker

### Claude's Discretion

- Exact stream-json parsing implementation for session ID extraction
- trap handler implementation details
- lib.sh internal function organization and naming

</decisions>

<specifics>
## Specific Ideas

- Claude output streaming: tee to both terminal display and a parser that extracts session_id from stream-json
- Section headers should look like: `-- Setting up worktree --` / `-- Launching Claude --` / `-- Post-Claude --`
- git-crypt unlock should silently skip if no keys found in ~/.ssh/git-crypt/ (not an error)
- State file phases map directly to resumption points: re-invocation reads phase and skips to the right step

</specifics>

<code_context>

## Existing Code Insights

### Reusable Assets

- gcmt module (`modules/apps/cli/gcmt/`): direct template for writeShellApplication + gum + scripts/ structure
- gcmt.sh color helpers (info/ok/warn/die): copy into lib.sh
- gcom tool (`modules/apps/cli/git/default.nix`): battle-tested worktree creation, git-crypt unlock, cleanup sequences, default_branch detection
- gcom's `is_worktree()`, `default_branch()`, `repo_path_with_branch()` helpers

### Established Patterns

- `pkgs.writeShellApplication` with `runtimeInputs` and `builtins.readFile ./scripts/<name>.sh`
- Auto-import via `modules/default.nix` (no manual imports needed)
- Module option namespace: `apps.cli.worktree-flow.enable`
- Skill deployment via `home.file` (see gemini-cli, stop-slop modules)
- `gum confirm` wrapped in `if` to handle exit codes under `set -e` (SF-04)

### Integration Points

- New module at `modules/apps/cli/worktree-flow/default.nix`
- SKILL.md replaces `modules/apps/cli/claude-code/skills/github-issue/SKILL.md`
- runtimeInputs: git, git-crypt, gum, gh, jq, coreutils, gnused, findutils
- `globals.user.name` for home-manager user targeting

</code_context>

<deferred>
## Deferred Ideas

None -- discussion stayed within phase scope

</deferred>

---

_Phase: 01-foundation_
_Context gathered: 2026-03-11_
