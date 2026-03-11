# Technology Stack

**Project:** worktree-flow (github-issue + hack commands)
**Researched:** 2026-03-11
**Overall confidence:** HIGH (all core components verified against live sources or in-codebase examples)

---

## Recommended Stack

### Shell Runtime

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| bash | system (via writeShellApplication) | Script language | writeShellApplication targets bash explicitly; set -euo pipefail is automatic; shellcheck runs at build time |
| writeShellApplication | nixpkgs built-in | Packaging wrapper | Already established pattern in this repo (gcmt, gcom, todoist-report); provides automatic PATH isolation, shellcheck, and bash -n validation at nix build time |

**Key properties of writeShellApplication (confirmed from nixpkgs source and nixhub):**
- Automatically prepends `set -o errexit -o nounset -o pipefail` -- do NOT add these manually
- Prepends a clean PATH built only from `runtimeInputs`
- Runs `shellcheck` + `bash -n` as checkPhase (unless excluded via `excludeShellChecks`)
- `runtimeEnv` attribute sets additional env vars that become part of the script wrapper
- `bashOptions` overrides the default set (rarely needed)
- Scripts in `./scripts/` read via `builtins.readFile ./scripts/script-name.sh` (gcmt pattern) -- use this over inline `text = ''...''` for any script over ~50 lines

### Interactive UI

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| gum | 0.17.0 (nixpkgs unstable) | Interactive terminal UI | Already a runtimeInput in gcmt; provides confirm, choose, filter, input, write, spin, log, style; no additional dependency |

**Use gum for (confirmed commands):**
- `gum confirm "message"` -- yes/no prompt, exit 0 = yes, exit 1 = no; use `|| true` pattern when no is valid
- `gum choose` with `--header` -- single selection from list
- `gum spin --title "message" -- command` -- spinner while background work runs
- `gum log --level info|warn|error "message"` -- structured log output (preferred over raw printf for status lines)
- `gum style --bold --foreground N "text"` -- styled output
- `gum write --value "$existing" --header "..."` -- multi-line review/edit (used in gcmt for body editing)

**Do NOT use gum for:**
- Non-interactive paths (CI, --auto mode of github-issue) -- gum blocks on TTY; guard all gum calls with a `NONINTERACTIVE` flag or `[[ -t 0 ]]` TTY check
- Simple logging that would work fine with printf -- gum adds overhead; use `gum log` for named steps, bare printf for progress detail

### Git Operations

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| git | system (via runtimeInputs) | Worktree lifecycle, branch management | All worktree operations use native git subcommands |
| git worktree | built into git | Isolated per-issue/per-hack workspaces | Shares .git directory; lightweight; already used in gcom with git-crypt unlock pattern |

**Critical git worktree commands for this project:**
```bash
git worktree add <path> -b <branch> <base-ref>    # create worktree + branch
git worktree list --porcelain                       # parse-safe listing
git worktree remove <path>                          # cleanup (fails if dirty)
git worktree remove --force <path>                  # force cleanup
git -C <path> <subcommand>                          # operate on worktree without cd
```

**Worktree path convention (from PROJECT.md):** `../.worktrees/issue-<number>/` or `../.worktrees/hack-<slug>/` (sibling to repo, not inside it).

**Branch naming (from PROJECT.md):** `fix/<slug>` or `feat/<slug>` based on content.

**Is-worktree detection (from gcom pattern):**
```bash
is_worktree() {
  [[ -f "$(git rev-parse --show-toplevel)/.git" ]]
}
```
A bare repo's `.git` is a directory; a worktree's `.git` is a file pointing back to the main repo.

### GitHub Automation

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| gh | 2.87.3 (nixpkgs unstable) | Issue fetch, PR creation, branch cleanup | Already in git module runtimeInputs and HM programs; all GitHub ops go through gh (per existing SKILL.md constraint) |

**Key gh commands for this project:**
```bash
gh issue view <number> --json title,body,labels,state   # fetch issue data
gh issue list --state open --json number,title          # list for picker
gh pr create --title "..." --body "..."                 # create PR
gh pr list --search "<branch>" --json number,state,headRefName
gh pr view <number> --json state,mergedAt               # check merged status
gh issue comment <number> --body "..."                  # post comment
```

**Important:** `gh pr create` and `gh issue create` do NOT support `--json` output flag as of early 2026 (confirmed GitHub issue #6366, #11196). Capture PR URL from stdout instead: `PR_URL=$(gh pr create ...)`.

### State Management

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| jq | nixpkgs | State file read/write, JSON parsing | Already used throughout the repo (todoist-report, check-pkg-updates); JSON state file in worktree root survives context compression |

**State file pattern (PROJECT.md requirement):**
```bash
STATE_FILE="${WORKTREE_PATH}/.worktree-state.json"

# Write state
jq -n \
  --arg phase "implement" \
  --arg issue_number "$ISSUE" \
  --arg branch "$BRANCH" \
  --arg pr_url "" \
  '{phase: $phase, issue_number: $issue_number, branch: $branch, pr_url: $pr_url}' \
  > "$STATE_FILE"

# Read state
PHASE=$(jq -r '.phase' "$STATE_FILE")
```

State file lives in the worktree root so `git status --porcelain` sees it; add to `.gitignore` or keep it untracked.

### Claude Code Invocation

| Technology | Version | Purpose | Why |
|------------|---------|---------|-----|
| claude (CLI) | in PATH via system packages | Launch implementation session | The core purpose of both commands is to wrap Claude Code in a worktree |

**Invocation pattern (from official Claude Code docs, verified March 2026):**

For interactive sessions (standard use case for `hack` and `github-issue`):
```bash
claude --allowedTools "Read,Write,Edit,Bash,Grep,Glob" \
  --append-system-prompt "$(cat SKILL.md)" \
  --resume "$SESSION_ID"   # optional: resume if state file has session_id
```

The `-p` / `--print` flag is for non-interactive headless mode. For `github-issue` and `hack`, the shell launches an **interactive** claude session in the worktree, not headless. Use `claude` (no `-p`) to drop into the full TUI.

**Session ID capture for resume support:**
```bash
# Capture session on first launch
SESSION_ID=$(claude --output-format json ... | jq -r '.session_id')
# Persist to state file, use --resume on re-entry
```

Note: `--continue` resumes the most recent conversation (fragile across terminals). `--resume SESSION_ID` is explicit and safer for the state file recovery pattern.

### Nix Module Pattern

**Module location:** `modules/apps/cli/worktree-flow/default.nix`
**Script location:** `modules/apps/cli/worktree-flow/scripts/`

Pattern to follow (gcmt is the canonical reference, not gcom which uses inline text):

```nix
{ lib, pkgs, config, globals, ... }:

let
  cfg = config.apps.cli.worktree-flow;

  github-issue = pkgs.writeShellApplication {
    name = "github-issue";
    runtimeInputs = with pkgs; [ git gh gum jq coreutils gnused ];
    text = builtins.readFile ./scripts/github-issue.sh;
  };

  hack = pkgs.writeShellApplication {
    name = "hack";
    runtimeInputs = with pkgs; [ git gum jq coreutils gnused ];
    text = builtins.readFile ./scripts/hack.sh;
  };
in
{
  options.apps.cli.worktree-flow.enable = lib.mkEnableOption
    "worktree-flow — Claude Code in git worktrees for github-issue and hack";

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ github-issue hack ];

    home-manager.users.${globals.user.name} = {
      home.file = {
        ".claude/skills/github-issue/SKILL.md".text =
          builtins.readFile ./skills/github-issue/SKILL.md;
      };
    };
  };
}
```

**coreutils** is always needed for `mktemp`, `date`, `basename`, `dirname`. **gnused** for `sed`. Both are small and safe to include by default.

---

## Alternatives Considered

| Category | Recommended | Alternative | Why Not |
|----------|-------------|-------------|---------|
| UI library | gum | fzf (already in gcom) | gum provides confirm/spin/log/style that fzf lacks; already established in gcmt; fzf stays for fuzzy file pickers where gum filter would be redundant |
| UI library | gum | dialog / whiptail | Old aesthetic, poor styling, no log levels; gum is the clear modern choice |
| State format | JSON (jq) | plain text key=value | jq already in PATH; JSON is structured, extensible, and easier to read back with precise field access |
| Worktree control | manual git worktree add | Claude Code EnterWorktree tool | EnterWorktree gives no control over naming, path, or state file location; manual is explicit and matches PROJECT.md requirement |
| Claude invocation | interactive claude (no -p) | claude -p headless | The commands exist to give the user an interactive Claude session in an isolated context; headless mode defeats the purpose |
| Script location | ./scripts/name.sh + builtins.readFile | inline text = ''...'' | Inline text means no syntax highlighting, no editor support, shellcheck only at build time; file-based is the gcmt/todoist-report established pattern |
| Language | bash | Python / Go | Project constraint: writeShellApplication + bash is explicitly specified; Python/Go would need a full build derivation |

---

## Installation (Nix)

No explicit installation step -- auto-discovered by `modules/default.nix` once the module directory exists. Enable on a host by adding:

```nix
apps.cli.worktree-flow.enable = true;
```

The two `writeShellApplication` derivations will be in `environment.systemPackages`.

---

## runtimeInputs Checklist

For `github-issue`:
- `git` -- worktree lifecycle
- `gh` -- GitHub issue/PR operations
- `gum` -- interactive prompts, spinners, logging
- `jq` -- state file read/write, gh JSON parsing
- `coreutils` -- mktemp, basename, date
- `gnused` -- sed for slug generation from branch names

For `hack`:
- `git` -- worktree lifecycle
- `gum` -- interactive prompts, diff review, merge confirmation
- `jq` -- state file read/write
- `coreutils` -- mktemp, basename, date
- `gnused` -- slug generation
- `difftastic` -- optional; only if rich diff display is needed in review step (already available via git config in git module)

Note: `claude` and `gh` are system-level packages installed via other modules, not runtimeInputs here. writeShellApplication isolates PATH, so `claude` would need to be in runtimeInputs if it is not globally available on PATH at runtime. Since `claude-code` module installs it to `environment.systemPackages`, it is accessible but only because the outer system PATH is inherited at invocation time -- verify this works or add `pkgs.claude-code` (or the local build) to runtimeInputs to be safe.

---

## Confidence Assessment

| Component | Confidence | Source |
|-----------|------------|--------|
| writeShellApplication pattern | HIGH | In-codebase (gcmt/git modules), nixpkgs docs |
| gum 0.17.0 commands | HIGH | Official GitHub releases page (Sep 2025) |
| claude -p vs interactive invocation | HIGH | Official Claude Code docs (code.claude.com/docs/en/headless) |
| gh 2.87.3 JSON output capabilities | MEDIUM | nixpkgs package.nix search result; gh pr create lacks --json confirmed via GitHub issues |
| State file JSON pattern | HIGH | Established pattern in todoist-report and check-pkg-updates in this repo |
| git worktree commands | HIGH | Official git-scm docs, confirmed via gcom in-codebase usage |
| Module namespace/auto-import | HIGH | modules/CLAUDE.md and existing modules |
| gnused in runtimeInputs | MEDIUM | Convention from nixpkgs scripts; coreutils sed is busybox-style; gnused is the safe explicit choice on NixOS |

---

## Sources

- Official Claude Code headless docs: https://code.claude.com/docs/en/headless
- gum latest release (v0.17.0, Sep 2025): https://github.com/charmbracelet/gum/releases
- gum command reference: https://github.com/charmbracelet/gum
- gh cli nixpkgs package: https://search.nixos.org/packages?show=gh
- gh pr create lacks --json: https://github.com/cli/cli/issues/6366
- gh issue create lacks --json: https://github.com/cli/cli/issues/11196
- git worktree docs: https://git-scm.com/docs/git-worktree
- writeShellApplication reference: https://nixos.asia/en/writeShellApplication
- In-codebase patterns: modules/apps/cli/gcmt/, modules/apps/cli/git/default.nix, modules/apps/cli/todoist-report/
