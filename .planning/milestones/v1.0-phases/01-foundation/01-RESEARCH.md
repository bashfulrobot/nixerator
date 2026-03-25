# Phase 1: Foundation - Research

**Researched:** 2026-03-11
**Domain:** NixOS Home Manager module scaffolding, shell scripting with writeShellApplication, shared lib.sh patterns, safety primitives
**Confidence:** HIGH

<user_constraints>

## User Constraints (from CONTEXT.md)

### Locked Decisions

**Claude Launch Contract**

- Launch with `claude --dangerously-skip-permissions` (worktree IS the sandbox)
- Prompt passed inline via `-p` with SKILL.md content, issue body, and repo context concatenated into a single prompt string
- Output format: `--output-format stream-json` for structured output parsing
- Session ID captured from stream-json output and written to state file for `--resume` on re-invocation
- On Claude exit: continue regardless of exit code (`|| true`), check for actual changes via `git diff --quiet HEAD`, proceed to post-Claude phase if changes exist
- Claude's output streams visible to user in real-time (tee to terminal and state parsing)

**State File Design**

- Linear phase tracking: setup, claude_running, claude_exited, pushing, pr_created (issue) / diff_review (hack), merged, cleanup_done
- Shared schema with `type` field ("issue" or "hack"); common fields shared, type-specific fields optional (pr_url for issue, description for hack)
- File lives at worktree root: `${WT_PATH}/.worktree-state.json`
- Filename: `.worktree-state.json` (dotfile, hidden from casual ls)
- Atomic writes: tmpfile + mv pattern (from WT-04 requirement)
- Schema includes: type, phase, issue/description, branch, worktree path, session_id, started_at, updated_at

**SKILL.md Placement**

- Deployed via worktree-flow module's `home.file`, not claude-code module (self-contained, no cross-module dependency)
- Deploys to `~/.claude/skills/github-issue/SKILL.md`
- Remove old SKILL.md from `modules/apps/cli/claude-code/skills/github-issue/` (worktree-flow owns it now)
- SKILL.md scope: commit conventions (type(scope): emoji, -S signing, no Co-Authored-By) AND PR body format (Summary/Test plan)

**Terminal Output Style**

- Reuse gcmt's color helper pattern: info/ok/warn/die with CYAN/GREEN/YELLOW/RED ANSI colors, defined in lib.sh
- Phase transitions announced with styled section headers via gum style (e.g., "-- Setting up worktree --")
- git-crypt auto-unlock: find first key in ~/.ssh/git-crypt/ automatically, single info() line, no interactive picker

### Claude's Discretion

- Exact stream-json parsing implementation for session ID extraction
- trap handler implementation details
- lib.sh internal function organization and naming

### Deferred Ideas (OUT OF SCOPE)

None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>

## Phase Requirements

| ID    | Description                                                                                  | Research Support                                                                        |
| ----- | -------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------- |
| NX-01 | New module at `modules/apps/cli/worktree-flow/` with `apps.cli.worktree-flow.enable` option  | Module scaffold pattern documented; auto-import confirmed via simpleAutoImport          |
| NX-02 | Both commands packaged via `pkgs.writeShellApplication` with explicit `runtimeInputs`        | Pattern verified from gcmt, todoist-report, gcom modules                                |
| NX-03 | Shared functions in `lib.sh` concatenated at build time via Nix string interpolation         | Nix string interpolation into writeShellApplication text field documented               |
| NX-04 | Scripts stored in `modules/apps/cli/worktree-flow/scripts/`                                  | Directory convention verified from gcmt and todoist-report                              |
| CL-01 | Shell script owns all lifecycle; Claude owns only implementation                             | Stub command structure with no Claude invocation needed for foundation                  |
| CL-02 | State file written before Claude launch, updated after Claude exits                          | Atomic write pattern (tmpfile+mv) documented; jq required in runtimeInputs              |
| CL-03 | All git fetch/setup operations complete before launching Claude                              | Sequencing enforced by linear bash execution before `claude` invocation                 |
| CL-04 | Simplified SKILL.md contains only commit conventions and PR body format                      | Content defined; deployment via home.file verified from gemini-cli/stop-slop modules    |
| CL-05 | Claude session ID tracked in state file for `--resume` on re-invocation                      | stream-json output format enables session_id extraction; jq parsing approach documented |
| SF-01 | Always uses `git push -u origin <branch>` on first push                                      | gcom pattern already uses `-u origin <branch>`; verified in lib.sh                      |
| SF-02 | Never pushes to main/master directly; validates current branch before push                   | Branch guard pattern documented                                                         |
| SF-03 | Guards against dirty working tree before worktree creation                                   | `git status --porcelain` guard pattern from gcom                                        |
| SF-04 | All gum prompts handle exit code 1 (No) and 130 (Ctrl+C) without silent death under `set -e` | `if gum confirm` construct documented; `set -e` behavior explained                      |
| SF-05 | git-crypt auto-unlock in new worktrees with key verification via `git crypt status`          | gcom has existing unlock pattern; auto-unlock (no picker) variant documented            |
| WT-03 | Script registers trap cleanup handler immediately after `git worktree add`                   | `trap` bash construct pattern documented for cleanup registration                       |
| WT-04 | State file writes are atomic (write to tmpfile, then `mv`)                                   | tmpfile+mv POSIX atomic write pattern documented                                        |

</phase_requirements>

## Summary

Phase 1 builds the module scaffold and all shared primitives that Phases 2 and 3 depend on. The codebase already contains battle-tested reference implementations: `gcmt` for `writeShellApplication` + color helpers, `gcom` for worktree lifecycle and git-crypt unlock, `gemini-cli` and `stop-slop` for `home.file` skill deployment. Nothing needs to be invented; the work is assembling known patterns into the new `worktree-flow` module structure.

The key insight is that lib.sh is not a runtime-loaded file -- it is inlined into each command's script text at Nix build time via string interpolation. This means shared functions are compile-time composed, not runtime-sourced. Both `github-issue` and `hack` commands get their own `writeShellApplication` derivations that each embed the full lib.sh content plus their specific logic.

The foundation phase produces stub commands that compile cleanly and put both binaries in PATH. The stubs need to contain enough implementation to validate all safety primitives: trap handlers, atomic state writes, gum safety patterns, git-crypt verification, and branch guards. Actual workflow logic (worktree creation, Claude invocation) is Phase 2+.

**Primary recommendation:** Copy color helpers verbatim from gcmt.sh, copy worktree/git-crypt helpers from gcom, then layer the new primitives (atomic state writes, trap registration, gum safety) on top in lib.sh.

## Standard Stack

### Core

| Library                    | Version        | Purpose                                                                                    | Why Standard                                                                    |
| -------------------------- | -------------- | ------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------- |
| pkgs.writeShellApplication | NixOS built-in | Package bash scripts as Nix derivations with automatic `set -euo pipefail`, PATH isolation | Used by every CLI module in this repo (gcmt, todoist-report, gcom, plannotator) |
| pkgs.gum                   | nixpkgs        | Interactive TUI prompts (confirm, choose, style, pager, write)                             | Already a dep in gcmt; established UI pattern for this project                  |
| pkgs.jq                    | nixpkgs        | JSON state file read/write, stream-json parsing                                            | Needed for `.worktree-state.json` and session_id extraction                     |
| pkgs.git                   | nixpkgs        | All git operations                                                                         | Required                                                                        |
| pkgs.git-crypt             | nixpkgs        | Worktree secret unlock                                                                     | Used in gcom; same pattern                                                      |
| pkgs.gh                    | nixpkgs        | GitHub CLI for PR/issue ops                                                                | Used in existing SKILL.md workflows                                             |
| pkgs.coreutils             | nixpkgs        | mktemp (atomic writes), date (timestamps), basename, etc.                                  | Required for POSIX atomic write tmpfile+mv                                      |
| pkgs.gnused                | nixpkgs        | Slug generation from issue title/description                                               | Already in gcom; verify if POSIX sed suffices (STATE.md blocker)                |
| pkgs.findutils             | nixpkgs        | `find` for git-crypt key discovery in ~/.ssh/git-crypt/                                    | Used in gcom for key discovery                                                  |

### Supporting

| Library                 | Version     | Purpose                                     | When to Use                                    |
| ----------------------- | ----------- | ------------------------------------------- | ---------------------------------------------- |
| pkgs.coreutils (mktemp) | nixpkgs     | Atomic tmpfile creation                     | Every state file write                         |
| builtins.readFile       | Nix builtin | Load script files from ./scripts/ directory | Preferred over inline text for files >20 lines |

### runtimeInputs for both commands

```nix
runtimeInputs = with pkgs; [
  git
  git-crypt
  gum
  gh
  jq
  coreutils
  gnused
  findutils
];
```

Note: `claude` (pkgs.claude-code) needs verification. `writeShellApplication` sandboxes PATH, so if `claude` is not in `runtimeInputs`, the binary will not be found at runtime. This is the open blocker noted in STATE.md. For Phase 1 stubs, `claude` invocation can be omitted (stubs do not actually run Claude), so this verification can be deferred to Phase 2.

### Alternatives Considered

| Instead of                               | Could Use                                      | Tradeoff                                                                        |
| ---------------------------------------- | ---------------------------------------------- | ------------------------------------------------------------------------------- |
| builtins.readFile + string interpolation | Inline text in default.nix                     | readFile is cleaner for >20 line scripts; inline is fine for small scripts      |
| gnused for slug generation               | Bash parameter expansion `${var//[^a-z0-9]/-}` | Bash built-in avoids gnused dep; test against real issue titles before deciding |
| jq for atomic state writes               | Pure bash + printf                             | jq guarantees valid JSON; pure bash risks malformed JSON                        |

## Architecture Patterns

### Recommended Project Structure

```
modules/apps/cli/worktree-flow/
├── default.nix          # Module definition, options, home.file for SKILL.md
├── scripts/
│   ├── lib.sh           # Shared primitives (colors, state I/O, git helpers, gum safety)
│   ├── github-issue.sh  # github-issue command logic (stub in Phase 1)
│   └── hack.sh          # hack command logic (stub in Phase 1)
└── skills/
    └── github-issue/
        └── SKILL.md     # Replaces modules/apps/cli/claude-code/skills/github-issue/SKILL.md
```

### Pattern 1: writeShellApplication with lib.sh inlining

**What:** lib.sh is inlined into each command via Nix string interpolation at build time. Both commands get independent derivations each containing the full lib.sh.

**When to use:** When two commands share helpers but must be independently packaged.

**Example:**

```nix
# Source: verified from gcmt/default.nix + todoist-report/default.nix patterns
let
  libSh = builtins.readFile ./scripts/lib.sh;

  github-issue-cmd = pkgs.writeShellApplication {
    name = "github-issue";
    runtimeInputs = with pkgs; [ git git-crypt gum gh jq coreutils gnused findutils ];
    text = ''
      ${libSh}
      ${builtins.readFile ./scripts/github-issue.sh}
    '';
  };

  hack-cmd = pkgs.writeShellApplication {
    name = "hack";
    runtimeInputs = with pkgs; [ git git-crypt gum gh jq coreutils gnused findutils ];
    text = ''
      ${libSh}
      ${builtins.readFile ./scripts/hack.sh}
    '';
  };
in
```

### Pattern 2: Module option declaration

**What:** Standard NixOS module option with `lib.mkEnableOption` or `lib.mkOption`, config gated behind `lib.mkIf`.

**Example:**

```nix
# Source: verified from modules/apps/cli/gcmt/default.nix + modules/apps/cli/git/default.nix
{
  options = {
    apps.cli.worktree-flow.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable worktree-flow: AI-powered isolated worktree workflows.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ github-issue-cmd hack-cmd ];

    home-manager.users.${globals.user.name} = {
      home.file.".claude/skills/github-issue/SKILL.md".text =
        builtins.readFile ./skills/github-issue/SKILL.md;
    };
  };
}
```

### Pattern 3: home.file for skill deployment

**What:** Deploy SKILL.md via `home.file` in `home-manager.users` block -- no cross-module dependency needed.

**Example:**

```nix
# Source: verified from modules/apps/cli/gemini-cli/default.nix (line 182)
# and modules/apps/cli/stop-slop/default.nix (line 32)
home-manager.users.${globals.user.name} = {
  home.file.".claude/skills/github-issue/SKILL.md".text =
    builtins.readFile ./skills/github-issue/SKILL.md;
};
```

### Pattern 4: Color helpers (from gcmt.sh)

**What:** Copy verbatim into lib.sh. These are the project-standard terminal output helpers.

```bash
# Source: modules/apps/cli/gcmt/scripts/gcmt.sh lines 4-13
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[1;33m'
CYAN=$'\033[0;36m'
NC=$'\033[0m'

info() { printf '%s▸ %s%s\n'  "$CYAN"   "$*" "$NC";        }
ok()   { printf '%s✔ %s%s\n'  "$GREEN"  "$*" "$NC";        }
warn() { printf '%s⚠ %s%s\n'  "$YELLOW" "$*" "$NC";        }
die()  { printf '%s✖ %s%s\n'  "$RED"    "$*" "$NC" >&2; exit 1; }
```

### Pattern 5: Atomic state file write

**What:** Write JSON to a tmpfile, then `mv` atomically into place. Prevents partial writes that leave state corrupted on interrupt.

```bash
# Source: POSIX tmpfile+mv; coreutils mktemp required in runtimeInputs
write_state() {
  local tmpfile
  tmpfile=$(mktemp "${WT_PATH}/.worktree-state.XXXXXX")
  printf '%s\n' "$1" > "$tmpfile"
  mv "$tmpfile" "${WT_PATH}/.worktree-state.json"
}

# State update via jq (preserve existing fields, update specific ones):
update_state_phase() {
  local new_phase="$1"
  local current
  current=$(cat "${WT_PATH}/.worktree-state.json")
  local updated
  updated=$(printf '%s' "$current" | jq --arg p "$new_phase" '.phase = $p | .updated_at = now | todate')
  write_state "$updated"
}
```

### Pattern 6: gum confirm safety under set -e

**What:** `writeShellApplication` sets `set -euo pipefail`. `gum confirm` exits with code 1 on "No" and 130 on Ctrl+C. Using it bare will kill the script silently. The fix: wrap in `if`.

```bash
# WRONG (dies silently on "No" or Ctrl+C under set -e):
gum confirm "Proceed?" && do_thing

# CORRECT (handles No and Ctrl+C gracefully):
if gum confirm "Proceed?"; then
  do_thing
else
  die "aborted by user"
fi
```

### Pattern 7: Trap cleanup handler

**What:** Register cleanup immediately after the resource is created, so Ctrl+C or `die` always triggers cleanup.

```bash
# Claude's discretion: exact implementation; this is the canonical approach
WT_PATH=""  # set before trap registration

cleanup() {
  if [[ -n "$WT_PATH" ]] && [[ -d "$WT_PATH" ]]; then
    warn "cleaning up worktree at $WT_PATH..."
    git worktree remove --force "$WT_PATH" 2>/dev/null || true
    git worktree prune 2>/dev/null || true
  fi
}
# Register AFTER git worktree add sets WT_PATH:
WT_PATH="..."
git worktree add "$WT_PATH" -b "$BRANCH" "$REMOTE/$DEFAULT_BRANCH"
trap cleanup EXIT INT TERM
```

### Pattern 8: git-crypt auto-unlock (no interactive picker)

**What:** Find the first key in ~/.ssh/git-crypt/ automatically. Single info() line. Skip silently if no keys found. Verify with `git crypt status`.

```bash
# Contrast with gcom's fzf-picker approach (CONTEXT.md locked: no picker)
unlock_git_crypt() {
  local key_dir="$HOME/.ssh/git-crypt"
  if [[ ! -d "$key_dir" ]]; then
    return 0
  fi
  local key
  key=$(find "$key_dir" -maxdepth 1 -type f | head -1)
  if [[ -z "$key" ]]; then
    return 0  # no keys found, skip silently
  fi
  info "unlocking git-crypt..."
  git -C "$WT_PATH" crypt unlock "$key"
  # Verify unlock succeeded
  git -C "$WT_PATH" crypt status >/dev/null 2>&1 || die "git-crypt unlock verification failed"
  ok "git-crypt unlocked"
}
```

### Anti-Patterns to Avoid

- **Inline large scripts in default.nix:** Use `builtins.readFile ./scripts/name.sh` for anything over ~15 lines; inline text becomes unmaintainable.
- **Runtime-sourcing lib.sh:** Do not `source /nix/store/.../lib.sh` at runtime. Inline it at build time via Nix string interpolation. The Nix store path is not stable across rebuilds during development.
- **`gum confirm` without `if`:** Always use `if gum confirm; then ... else ...; fi` under `set -e` (see Pattern 6).
- **Non-atomic state writes:** Never write directly to `.worktree-state.json`. Always use tmpfile+mv (see Pattern 5).
- **Cross-module skill deployment:** The SKILL.md for worktree-flow belongs in the worktree-flow module, not the claude-code module. No cross-module imports.
- **Manual import of new module:** Do NOT add the new module to any imports list. `modules/default.nix` uses `simpleAutoImport` which discovers all `.nix` files recursively except those in `disabled/`, `build/`, `cfg/`, `reference/` subdirectories.

## Don't Hand-Roll

| Problem                    | Don't Build                        | Use Instead                                             | Why                                                                  |
| -------------------------- | ---------------------------------- | ------------------------------------------------------- | -------------------------------------------------------------------- |
| JSON state file generation | String concatenation / printf JSON | `jq -n --arg ... '...'`                                 | Avoids quoting escapes, handles special chars, guarantees valid JSON |
| JSON state file reading    | Bash string parsing / grep         | `jq -r '.field'`                                        | Handles nested structures, null safety, type coercion                |
| Atomic file writes         | Custom locking scheme              | `mktemp` + `mv`                                         | POSIX atomic; mv on same filesystem is guaranteed atomic             |
| TUI prompts                | Custom readline / read             | `gum` (confirm, choose, style, pager, write)            | Already a dep; battle-tested; handles terminal sizing, colors        |
| Worktree path generation   | Custom slug functions              | `basename` + `tr`/`sed` for slug                        | Keep simple; complex slug logic is a separate concern                |
| Default branch detection   | Hardcode "main"                    | `git symbolic-ref refs/remotes/origin/HEAD` (from gcom) | Works across repos with different default branch names               |

**Key insight:** jq is non-negotiable for this module. Any custom JSON serialization in bash will break on issue titles containing quotes, backslashes, or newlines. Always use `jq -n --arg` for construction and `jq -r` for reading.

## Common Pitfalls

### Pitfall 1: writeShellApplication PATH isolation breaks `claude` binary

**What goes wrong:** `writeShellApplication` replaces `$PATH` with only the `runtimeInputs` derivations. If `pkgs.claude-code` is not in `runtimeInputs`, calling `claude` inside the script will fail with "command not found" even though `claude` is installed system-wide.
**Why it happens:** Nix sandboxes the runtime environment to prevent undeclared dependencies.
**How to avoid:** Add `pkgs.claude-code` (or whatever provides the `claude` binary) to `runtimeInputs`. Verify the package name with `nix search github:NixOS/nixpkgs/nixos-unstable#claude`.
**Warning signs:** Build succeeds, but running the command gives "claude: command not found" at runtime.

### Pitfall 2: lib.sh functions shadow writeShellApplication's set -euo pipefail

**What goes wrong:** `writeShellApplication` prepends `set -euo pipefail` before the script text. If lib.sh contains `set -e` again, or if any `set +e` is used carelessly, subshell behavior becomes unpredictable.
**Why it happens:** Multiple `set` calls interact non-intuitively, especially in subshells.
**How to avoid:** Omit `set -euo pipefail` from lib.sh entirely (let writeShellApplication inject it). Add a comment: `# NOTE: set -euo pipefail injected by writeShellApplication`.
**Warning signs:** gcmt.sh line 1 already has this comment; follow the same convention.

### Pitfall 3: gum confirm under set -e

**What goes wrong:** `gum confirm "Proceed?" && do_thing` -- on "No", gum exits 1, which under `set -e` terminates the entire script before `do_thing` or any cleanup runs.
**Why it happens:** `set -e` makes any non-zero exit kill the script, including intentional user "No" responses.
**How to avoid:** Always `if gum confirm; then ... else ...; fi`. SF-04 is a Phase 1 requirement specifically to prevent this.
**Warning signs:** Script exits with no output after a "No" confirmation.

### Pitfall 4: Nix string interpolation conflicts in inline shell

**What goes wrong:** When embedding shell in Nix string interpolation (`text = ''...''`), the `$` character is special in Nix. Shell variables like `$VAR` become Nix interpolations and fail to evaluate.
**Why it happens:** Nix double-single-quote strings interpret `${...}` as Nix interpolation.
**How to avoid:** Use `builtins.readFile ./scripts/name.sh` for the script files. When Nix interpolation IS needed to splice lib.sh, only the splice site uses `${libSh}`, and the script files themselves are plain bash.
**Warning signs:** Nix evaluation error mentioning undefined variable or unexpected identifier.

### Pitfall 5: Auto-import exclusion for scripts/ and skills/ subdirectories

**What goes wrong:** Naming a subdirectory something that matches autoimport exclude patterns causes it to be missed or included incorrectly.
**Why it happens:** `simpleAutoImport` excludes `disabled/`, `build/`, `cfg/`, `reference/`. All other subdirectory names are traversed.
**How to avoid:** `scripts/` and `skills/` are safe names (not in exclude list). Do not name subdirectories `build/` for non-derivation content.
**Warning signs:** Module works in isolation but the option is not available after rebuild.

### Pitfall 6: gnused vs POSIX sed for slug generation

**What goes wrong:** Some `sed` expressions that work with GNU sed fail with POSIX sed (BusyBox, macOS).
**Why it happens:** GNU sed extensions (`\w`, `\+`, etc.) are not POSIX.
**How to avoid:** For slug generation, prefer bash parameter expansion `${var,,}` (lowercase) and `${var//[^a-z0-9]/-}` (replace non-alphanumeric) to avoid the sed dependency entirely. STATE.md flags this as a pending decision.
**Warning signs:** `sed: invalid command` at runtime, or slugs with unexpected characters.

### Pitfall 7: jq `now | todate` availability

**What goes wrong:** `jq` versions before 1.6 do not have `now` or `todate`.
**Why it happens:** Older jq.
**How to avoid:** nixpkgs unstable ships jq 1.7.1+. Use `$(date -u +"%Y-%m-%dT%H:%M:%SZ")` in bash and pass as `--arg updated_at "$timestamp"` for maximum compatibility and clarity.
**Warning signs:** `jq: error: now/0 is not defined`.

## Code Examples

### Initial state file creation (jq-safe)

```bash
# Source: POSIX pattern; jq-n ensures valid JSON from bash variables
create_state() {
  local type="$1"    # "issue" or "hack"
  local branch="$2"
  local wt_path="$3"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local json
  json=$(jq -n \
    --arg type "$type" \
    --arg phase "setup" \
    --arg branch "$branch" \
    --arg wt_path "$wt_path" \
    --arg started_at "$timestamp" \
    --arg updated_at "$timestamp" \
    '{type: $type, phase: $phase, branch: $branch, wt_path: $wt_path,
      session_id: "", started_at: $started_at, updated_at: $updated_at}')
  write_state "$json"
}
```

### Phase transition

```bash
# Update phase field atomically
set_phase() {
  local new_phase="$1"
  local timestamp
  timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
  local current
  current=$(cat "${WT_PATH}/.worktree-state.json")
  local updated
  updated=$(printf '%s' "$current" | jq \
    --arg p "$new_phase" \
    --arg t "$timestamp" \
    '.phase = $p | .updated_at = $t')
  write_state "$updated"
}
```

### Stream-json session ID extraction (Claude's discretion area)

```bash
# claude --output-format stream-json emits newline-delimited JSON objects
# The session_id appears in the first object with type "system"
# This is a reasonable implementation; exact schema subject to claude-code version
extract_session_id() {
  # Read first system event from stream
  local line
  while IFS= read -r line; do
    local type
    type=$(printf '%s' "$line" | jq -r '.type // empty' 2>/dev/null)
    if [[ "$type" == "system" ]]; then
      printf '%s' "$line" | jq -r '.session_id // empty' 2>/dev/null
      return
    fi
  done
}
```

### Section header style

```bash
# Locked decision: section headers via gum style
section() {
  printf '\n'
  gum style --bold --foreground 6 "-- $* --"
  printf '\n'
}
# Usage:
# section "Setting up worktree"
# section "Launching Claude"
# section "Post-Claude"
```

### Branch guard (SF-02)

```bash
# Never push to main/master
assert_not_main() {
  local branch
  branch=$(git rev-parse --abbrev-ref HEAD)
  case "$branch" in
    main|master) die "refusing to push to protected branch: $branch" ;;
  esac
}
```

### Dirty tree guard (SF-03)

```bash
# Mirrors gcom's approach exactly
assert_clean_tree() {
  if [[ -n "$(git status --porcelain)" ]]; then
    die "working tree is not clean -- commit or stash first"
  fi
}
```

## State of the Art

| Old Approach                                         | Current Approach                                         | When Changed     | Impact                                                  |
| ---------------------------------------------------- | -------------------------------------------------------- | ---------------- | ------------------------------------------------------- |
| fzf interactive git-crypt key picker (gcom)          | Auto-select first key from ~/.ssh/git-crypt/             | Phase 1 decision | Simpler UX for automated flows                          |
| SKILL.md in claude-code module                       | SKILL.md in worktree-flow module                         | Phase 1 decision | Self-contained, no cross-module dep                     |
| claude-code skills/ with full lifecycle instructions | Simplified SKILL.md: commit conventions + PR format only | Phase 1 decision | Shell script owns lifecycle, Claude owns implementation |

**Deprecated/outdated:**

- `modules/apps/cli/claude-code/skills/github-issue/SKILL.md`: Will be removed when worktree-flow module is enabled. The worktree-flow module owns this file going forward.

## Open Questions

1. **`claude` binary in runtimeInputs**
   - What we know: `writeShellApplication` sandboxes PATH; gcom and gcmt do NOT call `claude` so they don't face this problem
   - What's unclear: The exact nixpkgs package name for `claude-code` (may be `pkgs.claude-code`, `pkgs.anthropic-claude-cli`, or similar)
   - Recommendation: Phase 1 stubs do not invoke `claude`, so defer to Phase 2. Before Phase 2, run `nix search github:NixOS/nixpkgs/nixos-unstable#claude` to confirm package name.

2. **gnused vs bash built-in slug generation**
   - What we know: gcom uses gnused; slug generation is needed for branch names like `fix/add-user-auth`
   - What's unclear: Whether issue titles with emoji, unicode, or special chars are handled correctly by bash `${var//...}` alone
   - Recommendation: Use bash `${var,,}` + `${var//[^a-z0-9]/-}` for Phase 1. Test against a few real issue titles. If edge cases arise, add gnused. This removes a dep and resolves the STATE.md blocker.

3. **stream-json session_id schema**
   - What we know: `claude --output-format stream-json` emits newline-delimited JSON; session tracking is available
   - What's unclear: The exact field names and event types in the current claude-code version
   - Recommendation: Session ID extraction is in Claude's Discretion area. Implement defensively: fall back to empty string if extraction fails rather than dying. Phase 1 stub does not need to call claude at all.

## Validation Architecture

### Test Framework

| Property           | Value                                                                      |
| ------------------ | -------------------------------------------------------------------------- |
| Framework          | None -- this is a Nix module; validation is `nixos-rebuild switch` success |
| Config file        | N/A                                                                        |
| Quick run command  | `just quiet-rebuild` (output to /tmp/nixerator-rebuild.log)                |
| Full suite command | `just quiet-rebuild`                                                       |

### Phase Requirements to Test Map

| Req ID | Behavior                                                     | Test Type | Automated Command                                                        | File Exists? |
| ------ | ------------------------------------------------------------ | --------- | ------------------------------------------------------------------------ | ------------ |
| NX-01  | Module option `apps.cli.worktree-flow.enable` is recognized  | smoke     | `nixos-rebuild switch` (zero errors)                                     | Wave 0       |
| NX-02  | Both `github-issue` and `hack` appear in PATH                | smoke     | `which github-issue && which hack` post-rebuild                          | Wave 0       |
| NX-03  | lib.sh functions available inside both commands              | smoke     | Run `github-issue --help` and `hack --help`, check zero exit             | Wave 0       |
| NX-04  | scripts/ directory contains lib.sh, github-issue.sh, hack.sh | manual    | `ls modules/apps/cli/worktree-flow/scripts/`                             | Wave 0       |
| SF-04  | gum confirm wrapped in `if` throughout lib.sh                | static    | `grep -n 'gum confirm' scripts/lib.sh scripts/*.sh` -- no bare usage     | Wave 0       |
| WT-04  | Atomic writes use tmpfile+mv                                 | static    | `grep -n 'mktemp' scripts/lib.sh` -- verify mv follows every mktemp      | Wave 0       |
| SF-05  | git crypt status called after unlock                         | static    | `grep -n 'crypt status' scripts/lib.sh`                                  | Wave 0       |
| SF-02  | Branch guard present                                         | static    | `grep -n 'main\|master' scripts/lib.sh` -- verify assert_not_main exists | Wave 0       |
| CL-04  | SKILL.md deployed to ~/.claude/skills/github-issue/SKILL.md  | smoke     | `ls ~/.claude/skills/github-issue/SKILL.md` post-rebuild                 | Wave 0       |

### Sampling Rate

- **Per task commit:** `just quiet-rebuild`
- **Per wave merge:** `just quiet-rebuild` + manual PATH check
- **Phase gate:** Clean rebuild with both binaries in PATH, zero shellcheck warnings (writeShellApplication runs shellcheck by default)

### Wave 0 Gaps

- [ ] `modules/apps/cli/worktree-flow/default.nix` -- module skeleton
- [ ] `modules/apps/cli/worktree-flow/scripts/lib.sh` -- shared primitives
- [ ] `modules/apps/cli/worktree-flow/scripts/github-issue.sh` -- stub
- [ ] `modules/apps/cli/worktree-flow/scripts/hack.sh` -- stub
- [ ] `modules/apps/cli/worktree-flow/skills/github-issue/SKILL.md` -- simplified version

## Sources

### Primary (HIGH confidence)

- `/home/dustin/git/nixerator/modules/apps/cli/gcmt/default.nix` + `scripts/gcmt.sh` -- writeShellApplication pattern, color helpers
- `/home/dustin/git/nixerator/modules/apps/cli/git/default.nix` -- gcom: worktree creation, git-crypt unlock, default_branch, is_worktree, repo_path_with_branch helpers
- `/home/dustin/git/nixerator/modules/apps/cli/gemini-cli/default.nix` -- home.file skill deployment pattern
- `/home/dustin/git/nixerator/modules/apps/cli/stop-slop/default.nix` -- alternative home.file skill deployment
- `/home/dustin/git/nixerator/modules/apps/cli/todoist-report/default.nix` -- writeShellApplication + scripts/ directory pattern
- `/home/dustin/git/nixerator/modules/apps/cli/plannotator/default.nix` -- home.file for commands deployment
- `/home/dustin/git/nixerator/lib/autoimport.nix` -- auto-import mechanism and exclusion rules
- `/home/dustin/git/nixerator/modules/CLAUDE.md` -- module conventions, namespace rules
- `/home/dustin/git/nixerator/.planning/phases/01-foundation/01-CONTEXT.md` -- locked decisions
- `/home/dustin/git/nixerator/.planning/REQUIREMENTS.md` -- all v1 requirements

### Secondary (MEDIUM confidence)

- `/home/dustin/git/nixerator/.planning/STATE.md` -- open blockers (claude binary, gnused decision)

### Tertiary (LOW confidence)

- Claude `--output-format stream-json` session_id schema -- inferred from general knowledge of claude-code CLI; verify against running instance before Phase 2

## Metadata

**Confidence breakdown:**

- Standard stack: HIGH -- all libraries verified in existing modules in this exact codebase
- Architecture: HIGH -- patterns copied directly from battle-tested modules (gcmt, gcom, gemini-cli)
- Pitfalls: HIGH -- writeShellApplication/set-e/gum interactions verified from existing code; gnused blocker documented in STATE.md
- Claude stream-json schema: LOW -- not verifiable from codebase; discretion area anyway

**Research date:** 2026-03-11
**Valid until:** 2026-04-10 (stable Nix patterns; 30-day window)
