{
  config,
  lib,
  pkgs,
  globals,
  secrets,
  ...
}:
let
  cfg = config.apps.cli.codex;
  sequentialThinkingMcpServer = pkgs.callPackage ../mcp-server-sequential-thinking/build { };
  context7ApiKey = (secrets.context7 or { }).apiKey or null;
  mcpServers = {
    sequential-thinking = {
      command = "${sequentialThinkingMcpServer}/bin/mcp-server-sequential-thinking";
    };
  } // lib.optionalAttrs (context7ApiKey != null) {
    context7 = {
      url = "https://mcp.context7.com/mcp";
      http_headers = {
        CONTEXT7_API_KEY = context7ApiKey;
      };
    };
  } // lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
    kong-konnect = {
      url = "https://us.mcp.konghq.com/";
      http_headers = {
        Authorization = "Bearer ${secrets.kong.kongKonnectPAT}";
      };
    };
  };
  escapeToml = s: lib.replaceStrings [ "\\" "\"" ] [ "\\\\" "\\\"" ] s;
  mkTomlArray = xs: "[ " + lib.concatStringsSep ", " (map (x: "\"${escapeToml x}\"") xs) + " ]";
  mkTomlHeader = name: "[mcp_servers.${name}]";
  mkTomlHeaders = name: "[mcp_servers.${name}.http_headers]";
  mkMcpServerToml = name: cfg:
    let
      baseLines =
        [ (mkTomlHeader name) ]
        ++ lib.optional (cfg ? command) "command = \"${escapeToml cfg.command}\""
        ++ lib.optional (cfg ? args) "args = ${mkTomlArray cfg.args}"
        ++ lib.optional (cfg ? url) "url = \"${escapeToml cfg.url}\"";
      headerLines =
        if cfg ? http_headers then
          [ "" (mkTomlHeaders name) ]
          ++ lib.mapAttrsToList (k: v: "${k} = \"${escapeToml v}\"") cfg.http_headers
        else
          [ ];
    in
    lib.concatStringsSep "\n" (baseLines ++ headerLines) + "\n";
  mcpServerFiles = lib.mapAttrs' (name: cfg: {
    name = ".codex/mcp-servers/${name}/mcp.toml";
    value = { text = mkMcpServerToml name cfg; };
  }) mcpServers;
  codexMcpPick = ''
    #!/usr/bin/env bash
    set -euo pipefail

    mcp_dir="$HOME/.codex/mcp-servers"
    if [[ ! -d "$mcp_dir" ]]; then
      echo "No MCP servers directory found at $mcp_dir" >&2
      exit 1
    fi

    if ! command -v fzf >/dev/null 2>&1; then
      echo "fzf is required but not installed." >&2
      exit 1
    fi

    mapfile -t servers < <(find "$mcp_dir" -mindepth 1 -maxdepth 1 -type d -printf "%f\n" | sort)
    if [[ ''${#servers[@]} -eq 0 ]]; then
      echo "No MCP servers found in $mcp_dir" >&2
      exit 1
    fi

    selected="$(printf '%s\n' "''${servers[@]}" | fzf -m --prompt="MCP servers> " --height=40% --layout=reverse)"
    if [[ -z "$selected" ]]; then
      exit 1
    fi

    output_dir=".codex"
    output="$output_dir/config.toml"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if ! grep -qE '(^|/)\.codex/config\.toml$' .gitignore 2>/dev/null; then
        echo "Warning: .gitignore does not include .codex/config.toml" >&2
      fi
    fi
    if [[ -e "$output" ]]; then
      read -r -p "''${output} exists. Overwrite? [y/N] " reply
      case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted."; exit 1 ;;
      esac
    fi

    mkdir -p "$output_dir"
    : > "$output"

    while IFS= read -r name; do
      file="$mcp_dir/$name/mcp.toml"
      if [[ ! -f "$file" ]]; then
        echo "Missing MCP config: $file" >&2
        exit 1
      fi
      cat "$file" >> "$output"
      printf "\n" >> "$output"
    done <<< "$selected"

    echo "Wrote $output"
  '';
  codexCommitSkill = ''
    ---
    name: commit
    description: Create conventional commits with emoji, push, tagging, or GitHub releases.
    disable-model-invocation: true
    argument-hint: "[--tag <major|minor|patch>] [--release]"
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
    feat:✨ fix:🐛 docs:📝 style:🎨 refactor:♻️ perf:⚡ test:✅ build:👷 ci:💚 chore:🔧 revert:⏪ security:🔒 deps:⬆️

    ## Examples:
    ✅ feat(auth): ✨ add OAuth2 login flow
    ✅ fix(api): 🐛 resolve race condition in token refresh
    ❌ ✨ feat(auth): add OAuth2 (emoji before type)
    ❌ feat: add OAuth2 (missing scope)

    ## Inputs
    - Optional flags via $ARGUMENTS:
      - `--tag <level>`: Tag version (major|minor|patch).
      - `--release`: Create GitHub release (requires --tag).

    ## Outputs
    - One or more signed commits.
    - Optional signed tag and GitHub release.

    ## Process:
    1. Run `gcommit` directly.
    2. Pass through optional `$ARGUMENTS` flags when provided.
       Example:
       `gcommit $ARGUMENTS`
  '';
  codexCommitSkillFile = pkgs.writeText "codex-commit-skill.md" codexCommitSkill;
in
{
  options = {
    apps.cli.codex = {
      enable = lib.mkEnableOption "Codex CLI tool";
    };
  };

  config = lib.mkIf cfg.enable {
    # System packages for MCP server selection helper
    environment.systemPackages = with pkgs; [
      (writeScriptBin "codex-mcp-pick" codexMcpPick)
      fzf
    ];

    home-manager.users.${globals.user.name} = {
      programs.codex = {
        enable = true;
        package = pkgs.llm-agents.codex;

        # Custom instructions (written to ~/.codex/AGENTS.md)
        custom-instructions = builtins.readFile ./CODEX.md;
      };

      home.file = mcpServerFiles;

      home.activation.installCodexCommitSkill = {
        after = [ "writeBoundary" ];
        before = [ ];
        data = ''
          # Write a real file (not a Home Manager symlink): Codex can ignore
          # symlinked local command/skill artifacts.
          # Ref: https://github.com/openai/codex/issues/4383
          install -Dm644 ${codexCommitSkillFile} "$HOME/.codex/skills/commit/SKILL.md"
        '';
      };
    };
  };
}
