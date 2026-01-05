{ user-settings, lib, pkgs, config, globals, ... }:
let
  cfg = config.apps.cli.gemini-cli;
  username = globals.user.name;

  commit-prompt = ''
    Format: `<type>(<scope>): <emoji> <description>`

    ## Rules:
    - No branding/secrets.
    - Type: feat|fix|docs|style|refactor|perf|test|build|ci|chore|revert|security|deps
    - Scope (REQUIRED for git-cliff): lowercase, kebab-case module name.
    - Emoji: AFTER colon (e.g., `feat(auth): ✨`). Subject: imperative, <72 chars.
    - Sign with `git commit -S`. Split unrelated changes atomically.

    ## Type→Emoji:
    feat:✨ fix:🐛 docs:📝 style:💄 refactor:♻️ perf:⚡ test:✅ build:👷 ci:💚 chore:🔧 revert:⏪ security:🔒 deps:⬆️

    ## Examples:
    ✅ feat(auth): ✨ add OAuth2 login flow
    ✅ fix(api): 🐛 resolve race condition in token refresh
    ❌ ✨ feat(auth): add OAuth2 (emoji before type)
    ❌ feat: add OAuth2 (missing scope)

    ## Arguments ($ARGUMENTS):
    --tag <level>: Tag version (major|minor|patch).
    --release: Create GitHub release (requires --tag).

    ## Process:
    1. Parse $ARGUMENTS flags.
    2. Inspect changes: `git status && git diff --cached`.
    3. Split into atomic commits (use `git reset HEAD <files>` + `git add`) if needed.
    4. For each: `git commit -S -m "<type>(<scope>): <emoji> <description>"`
    5. If --tag: `git tag -s v<version> -m "Release v<version>"`
    6. Always push: `git push && git push --tags` (if tagged).
    7. If --release: `gh release create v<version> --notes-from-tag`.
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
    home-manager.users.${username} = {
      home.packages = [ pkgs.gemini-cli ];

      # Create ~/.gemini/commands/commit.toml
      home.file.".gemini/commands/commit.toml".text = ''
        description = "Create conventional commits with emoji and optional push, tagging, or GitHub releases"
        prompt = """
        ${commit-prompt}
        """
      '';

      programs.fish.shellAbbrs = {
        gcommit = "gemini /commit";
      };
    };
  };
}
