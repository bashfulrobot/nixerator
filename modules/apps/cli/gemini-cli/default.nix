{ lib, pkgs, config, globals, ... }:
let
  cfg = config.apps.cli.gemini-cli;
  username = globals.user.name;

  # Settings JSON content
  settingsJson = builtins.toJSON {
    # General settings
    general = {
      # Enable Gemini 3 preview features
      previewFeatures = true;
    };
    # IDE integration
    ide = {
      enabled = true;
    };
    # Auth settings
    security = {
      auth = {
        selectedType = "oauth-personal";
      };
    };
  };
  humanizerSkill = builtins.readFile ./skills/humanizer/SKILL.md;

  # Guidelines shared between the slash command and the gcommit function
  commit-guidelines = ''
    Format: `<type>(<scope>): <emoji> <description>`
    Rules:
    - Type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|security|deps
    - Scope (REQUIRED): lowercase, kebab-case module name.
    - Emoji: AFTER colon (e.g., `feat(auth): ✨`). Subject: imperative, <72 chars.
    Type→Emoji: feat:✨ fix:🐛 docs:📝 style:🎨 refactor:♻️ perf:⚡ test:✅ build:👷 ci:💚 chore:🔧 revert:⏪ security:🔒 deps:⬆️
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

    msg=$(gemini -y --prompt "$prompt")

    if [[ -z "$msg" ]]; then
      echo "Failed to generate commit message." >&2
      exit 1
    fi

    git commit -S -m "$msg"
  '';

  commit-prompt = ''
    Format: `<type>(<scope>): <emoji> <description>`

    ## Rules:
    - No branding/secrets.
    - Type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|security|deps
    - Scope (REQUIRED for git-cliff): lowercase, kebab-case module name.
    - Emoji: AFTER colon (e.g., `feat(auth): ✨`). Subject: imperative, <72 chars.
    - Sign with `git commit -S`. Split unrelated changes atomically.

    ## Type→Emoji:
    feat:✨ fix:🐛 docs:📝 style:🎨 refactor:♻️ perf:⚡ test:✅ build:👷 ci:💚 chore:🔧 revert:⏪ security:🔒 deps:⬆️

    ## Examples:
    ✅ feat(auth): ✨ add OAuth2 login flow
    ✅ fix(api): 🐛 resolve race condition in token refresh
    ❌ ✨ feat(auth): add OAuth2 (emoji before type)
    ❌ feat: add OAuth2 (missing scope)

    ## Inputs
    - Optional flags via {{args}}:
      - `--tag <level>`: Tag version (major|minor|patch).
      - `--release`: Create GitHub release (requires --tag).

    ## Outputs
    - One or more signed commits.
    - Optional signed tag and GitHub release.

    ## Context

    ### Recent commits (match this style):
    ```
    !{git log --oneline -5}
    ```

    ### Working tree status:
    ```
    !{git status}
    ```

    ### Staged changes:
    ```diff
    !{git diff --staged}
    ```

    ## Preflight
    - Ensure you are in the repo root before running git commands.
    - Review the context above; avoid committing unrelated changes.
    - Stage all changes for this commit.

    ## Process:
    1. Parse {{args}} flags.
    2. Review the injected context above.
    3. Stage all changes: `git add -A`.
    4. Split into atomic commits (use `git reset HEAD <files>` + `git add`) if needed.
    5. For each: `git commit -S -m "<type>(<scope>): <emoji> <description>"`
    6. If --tag: `git tag -s v<version> -m "Release v<version>"`
    7. Always push: `git push && git push --tags` (if tagged).
    8. If --release: `gh release create v<version> --notes-from-tag`.
  '';
in
{
  options = {
    apps.cli.gemini-cli.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable gemini-cli CLI tool with commit helper.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      (writeScriptBin "gcommit" gcommitScript)
    ];

    home-manager.users.${username} = {
      home = {
        packages = [ pkgs.gemini-cli ];

        file = {
          # Create ~/.gemini/settings.json
          ".gemini/settings.json".text = settingsJson;

          # Create ~/.gemini/commands/commit.toml
          ".gemini/commands/commit.toml".text = ''
            description = "Create conventional commits with emoji and optional push, tagging, or GitHub releases"
            prompt = """
            ${commit-prompt}
            """
          '';

          # Install humanizer skill for Gemini CLI
          ".gemini/skills/humanizer/SKILL.md".text = humanizerSkill;
        };
      };

    };
  };
}
