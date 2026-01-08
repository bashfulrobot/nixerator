{ pkgs, lib, username, globals, ... }:

{
  # Home Manager configuration
  home = {
    # Home Manager needs a bit of information about you and the
    # paths it should manage (from globals)
    inherit username;
    inherit (globals.user) homeDirectory;

    # This value determines the Home Manager release that your
    # configuration is compatible with (from globals)
    inherit (globals.defaults) stateVersion;

    # User packages
    packages = with pkgs; [
      # Add your packages here
      htop
      tree
      ripgrep
      fd
      bat
    ];

    # Home Manager environment variables (from globals)
    sessionVariables = {
      EDITOR = lib.mkForce (lib.getExe pkgs.${globals.preferences.editor});
    };
  };

  programs = {
    # Let Home Manager install and manage itself
    home-manager.enable = true;

    codex = {
      enable = true;
      custom-instructions = ''
      ---
      description: Create conventional commits with emoji and optional push, tagging, or GitHub releases
      allowed-tools: ["Bash", "Grep", "Read"]
      ---

      You are a git commit enforcer. Create commits that strictly follow conventional commit and git-cliff standards.

      **CRITICAL RULES:**
      - NEVER include secrets in commit messages.
      - Sign all commits (`--gpg-sign`).
      - If staged changes are unrelated, create MULTIPLE atomic commits. Analyze changes with `git diff --cached` and use `git add` to stage files for each commit.

      **COMMIT FORMAT:**
      `<type>(<scope>): <emoji> <description>`

      - **Type:** Must be one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, security, deps.
      - **Scope:** Strongly recommended. Lowercase, kebab-case (e.g., `api-client`).
      - **Emoji:** Comes AFTER the colon.
      - **Subject:** Keep under 72 characters.
      - **Body/Footer:** Optional, for explanations or `BREAKING CHANGE:` / `Fixes #123`.

      **EMOJIS PER TYPE:**
      - feat: ✨
      - fix: 🐛
      - docs: 📝
      - style: 🎨
      - refactor: ♻️
      - perf: ⚡
      - test: ✅
      - build: 👷
      - ci: 💚
      - chore: 🔧
      - revert: ⏪
      - security: 🔒
      - deps: ⬆️

      **ARGUMENTS:**
      Parse these flags from `$ARGUMENTS` and execute the corresponding git/gh commands:
      - `--push`: Push commits and tags after creation.
      - `--tag <level>`: Create a signed semantic version tag (`major|minor|patch`).
      - `--release`: Create a GitHub release (requires `--tag`).

      **COMPLEX CHANGES:**
      For complex changes, consider using `gemini -p "@staged-files Analyze and group these changes for atomic commits"` for analysis.

      Always analyze staged changes first, split into atomic commits if needed, then apply the supported argument flags to the final command.
      '';
    };

  # Git configuration is now handled by modules/cli/git

  # Bash configuration
    bash = {
      enable = true;
      enableCompletion = true;
      bashrcExtra = ''
        # Add your custom bash configuration here
      '';
    };
  };
}
