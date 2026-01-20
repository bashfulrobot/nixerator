{ globals, lib, pkgs, config, secrets, ... }:

let
  cfg = config.apps.cli.opencode;
  username = globals.user.name;

  # Shared commit instructions
  commitInstructions = ''
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

  # Command (user-invoked via /commit)
  commitCommand = ''
    ---
    description: Create conventional commits with emoji, push, tagging, or GitHub releases.
    ---

    ${commitInstructions}
  '';

  # Skill (agent-invocable programmatically)
  commitSkill = ''
    ---
    name: commit
    description: Create conventional commits with emoji, push, tagging, or GitHub releases.
    ---

    ${commitInstructions}
  '';

  # Agent files directory (shared with claude-code)
  agentsDir = ../claude-code/agents;
in
{
  options = {
    apps.cli.opencode = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable opencode CLI tool with custom configuration.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # System packages for MCP server dependencies
    environment.systemPackages = with pkgs; [
      nodejs_24 # Includes npm and npx for MCP servers
    ];

    home-manager.users.${username} = {
      programs.opencode = {
        enable = true;
        package = pkgs.opencode;

        # Global rules (AGENTS.md)
        rules = builtins.readFile ./AGENTS.md;

        # Settings (config.json)
        settings = {
          # MCP server configuration
          mcp = {
            sequential-thinking = {
              type = "local";
              command = [ "${pkgs.nodejs_24}/bin/npx" "-y" "@modelcontextprotocol/server-sequential-thinking" ];
              enabled = true;
            };
          } // lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
            kong-konnect = {
              type = "remote";
              url = "https://us.mcp.konghq.com/";
              enabled = true;
              headers = {
                Authorization = "Bearer ${secrets.kong.kongKonnectPAT}";
              };
            };
          };
        };

        # Agents (subagents for specialized tasks)
        agents = {
          rust = builtins.readFile "${agentsDir}/rust.md";
          frontend = builtins.readFile "${agentsDir}/frontend.md";
          testing = builtins.readFile "${agentsDir}/testing.md";
          product = builtins.readFile "${agentsDir}/product.md";
          go = builtins.readFile "${agentsDir}/go.md";
          api = builtins.readFile "${agentsDir}/api.md";
          nix = builtins.readFile "${agentsDir}/nix.md";
          bash = builtins.readFile "${agentsDir}/bash.md";
        };

        # Commands (user-invoked via /commit)
        commands.commit = commitCommand;

        # Skills (agent-invocable programmatically)
        skills.commit = commitSkill;
      };

      # Fish abbreviations
      programs.fish.shellAbbrs = {
        oc = {
          position = "command";
          setCursor = true;
          expansion = "opencode \"%\"";
        };
      };
    };
  };
}
