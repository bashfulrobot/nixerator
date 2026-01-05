{ globals, lib, pkgs, config, secrets, ... }:

let
  cfg = config.apps.cli.claude-code;
  username = globals.user.name;

  # Commit command prompt
  commitPrompt = ''
    ---
    description: Create conventional commits with emoji, push, tagging, or GitHub releases.
    allowed-tools: ["Bash", "Grep", "Read"]
    ---

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
    apps.cli.claude-code = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable claude-code CLI tool with custom configuration.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # System packages for MCP server dependencies
    environment.systemPackages = with pkgs; [
      nodejs_24 # Includes npm and npx for MCP servers
    ];

    home-manager.users.${username} = {
      programs.claude-code = {
        enable = true;
        package = pkgs.claude-code;

        # Settings (JSON config)
        settings = {
          cleanupPeriod = 15;
          coAuthor = "";
          includeCoAuthoredBy = false;
        };

        # Memory file (CLAUDE.md - project rules and context)
        memory.text = builtins.readFile ./CLAUDE.md;

        # Agents (subagents for specialized tasks)
        agents = {
          rust = builtins.readFile ./agents/rust.md;
          frontend = builtins.readFile ./agents/frontend.md;
          testing = builtins.readFile ./agents/testing.md;
          product = builtins.readFile ./agents/product.md;
          go = builtins.readFile ./agents/go.md;
          api = builtins.readFile ./agents/api.md;
          nix = builtins.readFile ./agents/nix.md;
          bash = builtins.readFile ./agents/bash.md;
        };

        # Commands (slash commands like /commit)
        commands.commit = commitPrompt;

        # MCP Servers (Model Context Protocol integrations)
        mcpServers = {
          sequential-thinking = {
            command = "${pkgs.nodejs_24}/bin/npx";
            args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
          };
        } // lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
          kong-konnect = {
            type = "http";
            url = "https://us.mcp.konghq.com/";
            headers = {
              Authorization = "Bearer ${secrets.kong.kongKonnectPAT}";
            };
          };
        };
      };

      # Fish abbreviations
      programs.fish.shellAbbrs = {
        cc = {
          position = "command";
          setCursor = true;
          expansion = "claude -p \"%\"";
        };
      };
    };
  };
}
