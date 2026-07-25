{
  inputs,
  lib,
  pkgs,
  config,
  globals,
  ...
}:
let
  cfg = config.apps.cli.antigravity;

  # Antigravity's settings schema is flat -- none of the nested gemini-cli keys
  # (general.previewFeatures / ide.enabled / security.auth.selectedType) exist
  # here. Auth is not a settings key at all: `agy` stores credentials in the OS
  # keyring on first launch.
  settingsJson = builtins.toJSON {
    # "request-review" is the default; stated explicitly so a future upstream
    # default flip can't silently widen what the agent may run unattended.
    toolPermission = "request-review";
    verbosity = "low";
    enableTelemetry = false;
    showFeedbackSurvey = false;
  };

  # Guidelines shared between the commit skill and the gcommit script
  commit-guidelines = ''
    Format: `<type>(<scope>): <description>`
    Rules:
    - Type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|security|deps
    - Scope (REQUIRED): lowercase, kebab-case module name.
    - Subject: imperative, <72 chars.
  '';

  gcommitScript = ''
        #!/usr/bin/env bash
        set -euo pipefail

        custom_prompt=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            -p|--prompt)
              if [[ $# -lt 2 ]]; then
                echo "Missing value for $1" >&2
                exit 1
              fi
              custom_prompt="$2"
              shift 2
              ;;
            *)
              echo "Unsupported argument: $1" >&2
              echo "Use --prompt/-p for non-interactive mode." >&2
              exit 1
              ;;
          esac
        done

        git add -A

        diff=$(git diff --staged)
        if [[ -z "$diff" ]]; then
          echo "No changes to commit." >&2
          exit 1
        fi

        recent=$(git log --oneline -5 2>/dev/null || true)
        base_prompt=$(cat <<'EOF'
    Write a concise Conventional Commit message for the staged diff below. Output ONLY the commit message, nothing else.

    ${commit-guidelines}
    EOF
    )

        if [[ -n "$custom_prompt" ]]; then
          prompt=$(printf "%s\n\n%s\n\nRecent commits (match this style):\n%s\n\nDiff:\n%s\n" "$custom_prompt" "$base_prompt" "$recent" "$diff")
        else
          prompt=$(printf "%s\n\nRecent commits (match this style):\n%s\n\nDiff:\n%s\n" "$base_prompt" "$recent" "$diff")
        fi

        # The whole prompt goes in the --print argument: agy ignores stdin
        # entirely when a prompt arrives via flag (antigravity-cli#76, fixed in
        # 1.1.1). `< /dev/null` guards the historical inherited-pipe hang.
        msg=$(agy --dangerously-skip-permissions --print-timeout 120s --print "$prompt" < /dev/null)

        if [[ -z "$msg" ]]; then
          echo "Failed to generate commit message." >&2
          exit 1
        fi

        git commit -S -m "$msg"
  '';

  # Antigravity has no TOML slash commands: skills are the slash-command
  # mechanism, so this ships as a skill rather than a `commands/commit.toml`.
  # Consequently the gemini-cli `!{...}` shell-injection and `{{args}}`
  # placeholders are gone -- the agent runs the git commands itself.
  commit-skill = ''
    ---
    name: commit
    description: Create conventional commits with optional push, tagging, or GitHub releases
    ---

    # Commit

    ${commit-guidelines}

    ## Rules
    - No branding/secrets.
    - Sign with `git commit -S`. Split unrelated changes atomically.

    ## Examples
    ✅ feat(auth): add OAuth2 login flow
    ✅ fix(api): resolve race condition in token refresh
    ❌ feat: add OAuth2 (missing scope)

    ## Inputs
    Optional flags, taken from how the user invoked this skill:
    - `--tag <level>`: Tag version (major|minor|patch).
    - `--release`: Create GitHub release (requires --tag).

    ## Outputs
    - One or more signed commits.
    - Optional signed tag and GitHub release.

    ## Preflight
    - Ensure you are in the repo root before running git commands.
    - Gather context yourself, then review it before writing anything:
      - `git log --oneline -5` -- match the existing message style.
      - `git status` -- see the working tree.
      - `git diff --staged` -- see what is actually being committed.
    - Avoid committing unrelated changes.

    ## Process
    1. Parse the flags above from the invocation.
    2. Review the context gathered in Preflight.
    3. Stage all changes: `git add -A`.
    4. Split into atomic commits (use `git reset HEAD <files>` + `git add`) if needed.
    5. For each: `git commit -S -m "<type>(<scope>): <description>"`
    6. If --tag: `git tag -s v<version> -m "Release v<version>"`
    7. Always push: `git push && git push --tags` (if tagged).
    8. If --release: `gh release create v<version> --notes-from-tag`.
  '';
in
{
  options = {
    apps.cli.antigravity.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Antigravity CLI (`agy`) with commit helper.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "gcommit" gcommitScript)
    ];

    home-manager.users.${globals.user.name} = {
      home = {
        # From jacopone/antigravity-nix rather than llm-agents:
        # Ships the CLI (agy), Antigravity 2.0 app, and IDE packages.
        packages = [
          pkgs.google-antigravity-cli
          pkgs.google-antigravity
          pkgs.google-antigravity-ide
        ];

        file = {
          # Create ~/.gemini/antigravity-cli/settings.json -- agy keeps its own
          # config under the legacy ~/.gemini tree.
          ".gemini/antigravity-cli/settings.json".text = settingsJson;

          # Skills double as slash commands. ~/.gemini/config/skills is the one
          # global location both the agy CLI and the Antigravity IDE read.
          #
          # Claude Code is the source of truth for shared skills:
          # Directory symlinks keep all files/subdirectories (references, scripts)
          # 100% DRY without needing to manually list sub-paths.
          ".gemini/config/skills/commit".source = ../claude-code/config/skills/commit;
          ".gemini/config/skills/humanizer/SKILL.md".source = inputs.humanizer-skill + "/SKILL.md";
          ".gemini/config/skills/text-polish".source = ../claude-code/config/skills/text-polish;
        };
      };

    };
  };
}
