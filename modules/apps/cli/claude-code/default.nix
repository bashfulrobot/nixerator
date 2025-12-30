{ globals, lib, pkgs, config, inputs, secrets, ... }:

let
  cfg = config.apps.cli.claude-code;
  username = globals.user.name;
in
{
  options = {
    apps.cli.claude-code = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable claude-code CLI tool with commit helper.";
      };
    };
  };

  config = lib.mkIf cfg.enable {

    # MCP server configuration script
    environment.systemPackages = with pkgs; [
      # keep-sorted start case=no numeric=yes
      inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code
      nodejs_24 # Includes npm and npx for MCP servers
      # keep-sorted end

      # Script to configure MCP servers
      (pkgs.writeShellScriptBin "configure-claude-mcp" ''
        #!/usr/bin/env bash
        set -e

        echo "Configuring Claude MCP servers..."

        # Remove existing servers (ignore errors if they don't exist)
        claude mcp remove --scope user sequential-thinking 2>/dev/null || true
        claude mcp remove --scope user kong-konnect 2>/dev/null || true

        # Add sequential-thinking MCP server
        claude mcp add --transport stdio --scope user sequential-thinking -- ${pkgs.nodejs_24}/bin/npx -y @modelcontextprotocol/server-sequential-thinking
        echo "✓ Added sequential-thinking MCP server"

        # Add Kong Konnect MCP server if PAT is configured
        ${lib.optionalString (secrets.kong.kongKonnectPAT or null != null) ''
          claude mcp add --transport http --scope user kong-konnect https://us.mcp.konghq.com/ -H "Authorization: Bearer ${secrets.kong.kongKonnectPAT}"
          echo "✓ Added kong-konnect MCP server"
        ''}

        echo "MCP server configuration complete!"
      '')
    ];

    # Systemd user service to configure MCP servers on login
    systemd.user.services.configure-claude-mcp = {
      description = "Configure Claude Code MCP servers";
      wantedBy = [ "default.target" ];
      after = [ "network-online.target" ];
      serviceConfig = {
        Type = "oneshot";
        ExecStart = "${pkgs.writeShellScript "configure-claude-mcp-service" ''
          #!/usr/bin/env bash

          # Remove existing servers (ignore errors if they don't exist)
          ${lib.getExe inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code} mcp remove --scope user sequential-thinking 2>/dev/null || true
          ${lib.getExe inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code} mcp remove --scope user kong-konnect 2>/dev/null || true

          # Add sequential-thinking MCP server
          ${lib.getExe inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code} mcp add --transport stdio --scope user sequential-thinking -- ${pkgs.nodejs_24}/bin/npx -y @modelcontextprotocol/server-sequential-thinking

          # Add Kong Konnect MCP server if PAT is configured
          ${lib.optionalString (secrets.kong.kongKonnectPAT or null != null) ''
            ${lib.getExe inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.claude-code} mcp add --transport http --scope user kong-konnect https://us.mcp.konghq.com/ -H "Authorization: Bearer ${secrets.kong.kongKonnectPAT}"
          ''}
        ''}";
        RemainAfterExit = true;
      };
    };

    # Home Manager user configuration
    home-manager.users.${username} = { lib, ... }: {
      home.file = {
        ".claude/CLAUDE.md".source = ./CLAUDE.md;

        ".claude/settings.json".text = builtins.toJSON {
          cleanupPeriod = 15;
          coAuthor = "";
          includeCoAuthoredBy = false;
        };

        # Deploy subagents to ~/.claude/agents/
        ".claude/agents/rust.md".source = ./agents/rust.md;
        ".claude/agents/frontend.md".source = ./agents/frontend.md;
        ".claude/agents/testing.md".source = ./agents/testing.md;
        ".claude/agents/product.md".source = ./agents/product.md;
        ".claude/agents/go.md".source = ./agents/go.md;
        ".claude/agents/api.md".source = ./agents/api.md;
        ".claude/agents/nix.md".source = ./agents/nix.md;
        ".claude/agents/bash.md".source = ./agents/bash.md;
        ".claude/commands/commit.md".text = ''
          ---
          description: Create conventional commits with emoji and optional push, tagging, or GitHub releases
          allowed-tools: ["Bash", "Grep", "Read"]
          ---

          You are a strict git commit enforcer. Create commits that follow these EXACT rules from the user's CLAUDE.md:

          ## Git Commit Guardrails

          **CRITICAL: NEVER include Claude branding or attribution in commit messages. EVER.**

          **CRITICAL: NEVER include secrets values in commit messages. EVER.**

          When creating git commits, strictly adhere to these requirements:
          • Use conventional commits format with semantic prefixes and emoji
          • Craft commit messages based strictly on actual git changes, not assumptions
          • Sign all commits for authenticity and integrity (--gpg-sign)
          • Never use Claude branding or attribution in commit messages
          • Follow DevOps best practices as a senior professional
          • Message format: `<type>(<scope>): <emoji> <description>`
          • Types: feat, fix, docs, style, refactor, perf, test, build, ci, chore, security, deps
          • Keep subject line under 72 characters, detailed body when necessary
          • Use imperative mood: "add feature" not "added feature"
          • Reference issues/PRs when applicable: "fixes #123" or "closes #456"
          • Ensure commits represent atomic, logical changes
          • Verify all staged changes align with commit message intent
          • Never use the lipstick emoji in commits, just the artists pallet for design or visual commit messages.

          ## git-cliff Changelog Compatibility

          **CRITICAL: Commits MUST be parseable by git-cliff for automated changelog generation.**

          ### Required Format (STRICT):
          ```
          <type>(<scope>): <emoji> <description>

          [optional body]

          [optional footer]
          ```

          ### Format Rules:
          1. **Type is MANDATORY** - Must be one of: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert, security, deps
          2. **Scope is STRONGLY RECOMMENDED** - Use parentheses: `(scope)` - identifies the component/module affected
          3. **Emoji AFTER the colon** - Format: `type(scope): <emoji> description`
          4. **Subject line** - Must be on the same line as type/scope, separated by `: `
          5. **No emojis before type** - ❌ `✨ feat(auth):` ✅ `feat(auth): ✨`
          6. **No prefixes before type** - ❌ `🔧 chore(deps):` ✅ `chore(deps): 🔧`

          ### Examples of CORRECT commits (git-cliff compatible):
          ```
          feat(auth): ✨ add OAuth2 login flow
          fix(api): 🐛 resolve race condition in token refresh
          docs(readme): 📝 update installation instructions
          refactor(database): ♻️ migrate from ORM to raw SQL queries
          chore(deps): ⬆️ update flake inputs for v0.0.4
          ```

          ### Examples of INCORRECT commits (git-cliff will reject/warn):
          ```
          ❌ ✨ feat(auth): add OAuth2 login flow          (emoji before type)
          ❌ feat: add OAuth2 login flow                   (missing scope - not ideal)
          ❌ Add OAuth2 login flow                         (missing type entirely)
          ❌ feat add OAuth2 login flow                    (missing colon separator)
          ❌ FEAT(auth): ✨ add OAuth2                     (uppercase type)
          ❌ feature(auth): ✨ add OAuth2                  (invalid type name)
          ```

          ### Scope Guidelines:
          - Use lowercase, kebab-case for multi-word scopes: `feat(api-client):`
          - Be specific but concise: `fix(waybar)` not `fix(desktop-environment-status-bar)`
          - Use component/module names: `feat(hyprland)`, `docs(plymouth)`, `fix(keyring)`
          - For cross-cutting changes, use logical grouping: `refactor(modules)`, `chore(deps)`

          ### Body and Footer (Optional):
          - Add blank line after subject before body
          - Use body for detailed explanation of WHY (not what - git diff shows what)
          - Use footer for breaking changes: `BREAKING CHANGE: description`
          - Use footer for issue references: `Fixes #123` or `Closes #456`

          ## Multiple Commits for Unrelated Changes

          **CRITICAL: If staged changes span multiple unrelated scopes or types, create MULTIPLE separate commits.**

          Process for multiple commits:
          1. Analyze all staged changes and group by scope/type
          2. Use `git reset HEAD <files>` to unstage files
          3. Use `git add <files>` to stage files for each atomic commit
          4. Create separate commits for each logical grouping
          5. Ensure each commit is atomic and represents one logical change

          Examples of when to split:
          - Frontend changes + backend changes = 2 commits
          - Feature addition + bug fix = 2 commits
          - Documentation + code changes = 2 commits
          - Different modules/components = separate commits

          ## Conventional Commit Types with Emojis:
          - feat: ✨ New feature
          - fix: 🐛 Bug fix
          - docs: 📝 Documentation changes
          - style: 💄 Code style changes (formatting, etc.)
          - refactor: ♻️ Code refactoring
          - perf: ⚡ Performance improvements
          - test: ✅ Adding or updating tests
          - build: 👷 Build system changes
          - ci: 💚 CI/CD changes
          - chore: 🔧 Maintenance tasks
          - revert: ⏪ Revert previous commit
          - security: 🔒 Security improvements
          - deps: ⬆️ Dependency updates

          ## Available Arguments:
          Parse these flags from $ARGUMENTS:
          - `--push`: Push to remote repository after committing
          - `--tag <level>`: Create semantic version tag (major|minor|patch)
          - `--release`: Create GitHub release after tagging (requires --tag)

          ## Gemini CLI Integration

          **Use Gemini CLI for large codebase analysis when beneficial:**

          When you have complex staged changes that are difficult to analyze in a single context window, use:
          ```bash
          gemini -p "@staged-files Analyze these staged changes and suggest how to group them into atomic commits with appropriate types and scopes"
          ```

          Consider using Gemini CLI when:
          - Many files are staged (>10 files)
          - Changes span multiple directories/modules
          - Unsure how to properly scope the changes
          - Need to understand the relationship between changes

          ## Process:
          1. Parse arguments from $ARGUMENTS for the 3 supported flags
          2. Run `git status` to see staged changes
          3. If complex changes, consider using Gemini CLI for analysis
          4. Run `git diff --cached` to analyze the actual changes
          5. Determine if changes need to be split into multiple commits
          6. For each atomic commit:
             - Stage appropriate files with `git add`
             - Create commit message: `<type>(<scope>): <emoji> <description>`
             - Execute: `git commit -S -m "message"`
          7. If `--tag` specified on final commit:
             - Get current version: `git describe --tags --abbrev=0` (default v0.0.0)
             - Calculate next version based on level
             - Create signed tag: `git tag -s v<version> -m "Release v<version>"`
          8. If `--push` specified:
             - Push commits: `git push`
             - Push tags if created: `git push --tags`
          9. If `--release` specified (requires tag):
             - Create GitHub release: `gh release create v<version> --title "Release v<version>" --notes-from-tag`

          Arguments: $ARGUMENTS

          Always analyze staged changes first, split into atomic commits if needed, then apply the 3 supported argument flags.
        '';
      };

      programs.fish.shellAbbrs = {
        cc = {
          position = "command";
          setCursor = true;
          expansion = "claude -p \"%\"";
        };
        # Claude Code slash command shortcuts
        ccommit = "claude -p '/commit --push'";
      };
    };
  };
}