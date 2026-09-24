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
    customInstructions = "When creating git commits, ALWAYS use the `gcommit` script. Never run raw unformatted git commit commands directly.\n\n${commit-guidelines}";
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

in
{
  options = {
    apps.cli.antigravity.enable = lib.mkEnableOption "Antigravity CLI (`agy`) with commit helper";
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

          # Global instructions read by Antigravity CLI and IDE:
          ".gemini/instructions.md".text = ''
            # Global Antigravity Instructions

            - **Git Commits**: ALWAYS use the `gcommit` script for creating git
              commits (drafts a Conventional Commit message from the staged
              diff, then signs it). Never run raw unformatted git commit
              commands directly.

              ${commit-guidelines}
          '';

          # Skills double as slash commands. ~/.gemini/config/skills is the one
          # global location both the agy CLI and the Antigravity IDE read.
          #
          # Claude Code is the source of truth for shared skills:
          # Directory symlinks keep all files/subdirectories (references, scripts)
          # 100% DRY without needing to manually list sub-paths.
          #
          # `commit`, `github-issues-auto`, `log-github-issue`, and `text-polish`
          # used to be symlinked from claude-code/config/skills/ too, but commit
          # 0f5521d2 (2026-09-08) retired those directories in favor of the
          # dk@claude-skills marketplace plugin -- a Claude Code-only mechanism
          # antigravity/gemini has no equivalent consumer for. There is currently
          # no vendored source left to link them from. Git commits fall back to
          # the gcommit script/instructions.md above instead of the gone
          # `commit` skill; the other three simply aren't available to agy.
          ".gemini/config/skills/github-issue".source = ../worktree-flow/skills/github-issue;
          ".gemini/config/skills/humanizer/SKILL.md".source = inputs.humanizer-skill + "/SKILL.md";
        };
      };

    };
  };
}
