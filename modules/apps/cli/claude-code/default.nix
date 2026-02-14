{ globals, lib, pkgs, config, secrets, ... }:

let
  cfg = config.apps.cli.claude-code;
  username = globals.user.name;
  homeDir = "/home/${username}";
  kubeconfigFile = "${homeDir}/.kube/mcp-viewer.kubeconfig";
  context7ApiKey = (secrets.context7 or { }).apiKey or null;
  zaiApiKey = (secrets.zai or { }).apiKey or null;
  mcpServers = {
    sequential-thinking = {
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [ "-y" "@modelcontextprotocol/server-sequential-thinking" ];
    };
    kubernetes-mcp-server = {
      command = "${pkgs.nodejs_24}/bin/npx";
      args = [ "-y" "kubernetes-mcp-server@latest" "--read-only" ];
      env = {
        KUBECONFIG = kubeconfigFile;
      };
    };
    # Go code intelligence via official gopls MCP (detached mode)
    # Tools: go_diagnostics, go_references, go_search, go_symbol_references, etc.
    gopls = {
      command = "${pkgs.gopls}/bin/gopls";
      args = [ "mcp" ];
    };
  } // lib.optionalAttrs (context7ApiKey != null) {
    context7 = {
      type = "http";
      url = "https://mcp.context7.com/mcp";
      headers = {
        CONTEXT7_API_KEY = context7ApiKey;
      };
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
  mkMcpServerJson = name: cfg: builtins.toJSON {
    mcpServers = {
      "${name}" = cfg;
    };
  };
  mcpServerFiles = lib.mapAttrs' (name: cfg: {
    name = ".claude/mcp-servers/${name}/.mcp.json";
    value = { text = mkMcpServerJson name cfg; };
  }) mcpServers;

  # Kubernetes MCP setup script
  k8s-mcp-setup = ''
    #!/usr/bin/env fish

    set -l KUBECONFIG_FILE "${kubeconfigFile}"
    set -l NAMESPACE "mcp"
    set -l SERVICE_ACCOUNT "mcp-viewer"
    set -l CONTEXT_NAME "mcp-viewer-context"
    set -l CLUSTER_NAME "mcp-viewer-cluster"
    set -l TOKEN_DURATION "24h"

    function show_help
        echo "k8s-mcp-setup - Configure Kubernetes MCP Server for Claude Code"
        echo ""
        echo "Usage: k8s-mcp-setup [COMMAND]"
        echo ""
        echo "Commands:"
        echo "  setup     Create namespace, service account, and generate kubeconfig"
        echo "  renew     Renew the service account token"
        echo "  status    Check setup status and test connectivity"
        echo "  cleanup   Remove all MCP resources from the cluster"
        echo "  help      Show this help message"
        echo ""
        echo "Examples:"
        echo "  k8s-mcp-setup setup    # Initial setup"
        echo "  k8s-mcp-setup renew    # Refresh expired token"
        echo "  k8s-mcp-setup status   # Verify configuration"
    end

    function check_kubectl
        if not command -q kubectl
            echo "Error: kubectl is not installed or not in PATH"
            return 1
        end
        if not kubectl cluster-info &>/dev/null
            echo "Error: Cannot connect to Kubernetes cluster"
            echo "Ensure your default kubeconfig is configured correctly"
            return 1
        end
        return 0
    end

    function setup_mcp
        echo "Setting up Kubernetes MCP Server..."
        echo ""

        # Create namespace
        echo "Creating namespace '$NAMESPACE'..."
        if kubectl get namespace $NAMESPACE &>/dev/null
            echo "  Namespace already exists, skipping"
        else
            kubectl create namespace $NAMESPACE
            or return 1
        end

        # Create service account
        echo "Creating service account '$SERVICE_ACCOUNT'..."
        if kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE &>/dev/null
            echo "  Service account already exists, skipping"
        else
            kubectl create serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE
            or return 1
        end

        # Create cluster role binding for read-only access
        echo "Creating cluster role binding for read-only access..."
        if kubectl get clusterrolebinding mcp-viewer-crb &>/dev/null
            echo "  Cluster role binding already exists, skipping"
        else
            kubectl create clusterrolebinding mcp-viewer-crb \
                --clusterrole=view \
                --serviceaccount=$NAMESPACE:$SERVICE_ACCOUNT
            or return 1
        end

        # Generate kubeconfig
        echo "Generating kubeconfig at $KUBECONFIG_FILE..."
        generate_kubeconfig
        or return 1

        echo ""
        echo "Setup complete!"
        echo "Kubeconfig saved to: $KUBECONFIG_FILE"
        echo ""
        echo "Token expires in $TOKEN_DURATION. Run 'k8s-mcp-setup renew' to refresh."
    end

    function generate_kubeconfig
        # Get token
        set -l TOKEN (kubectl create token $SERVICE_ACCOUNT --duration=$TOKEN_DURATION -n $NAMESPACE)
        or return 1

        # Get API server URL
        set -l API_SERVER (kubectl config view --minify -o jsonpath='{.clusters[0].cluster.server}')

        # Get CA data
        set -l CA_DATA (kubectl config view --minify --raw -o jsonpath='{.clusters[0].cluster.certificate-authority-data}')

        # Ensure .kube directory exists
        mkdir -p (dirname $KUBECONFIG_FILE)

        # Handle CA - either from file or inline data
        set -l CA_FILE (kubectl config view --minify -o jsonpath='{.clusters[0].cluster.certificate-authority}')

        if test -n "$CA_FILE" -a -f "$CA_FILE"
            # CA is in a file
            kubectl config --kubeconfig="$KUBECONFIG_FILE" set-cluster $CLUSTER_NAME \
                --server="$API_SERVER" \
                --certificate-authority="$CA_FILE" \
                --embed-certs=true
        else
            # CA is inline, write to temp file
            set -l TEMP_CA (mktemp)
            echo $CA_DATA | base64 -d > $TEMP_CA
            kubectl config --kubeconfig="$KUBECONFIG_FILE" set-cluster $CLUSTER_NAME \
                --server="$API_SERVER" \
                --certificate-authority="$TEMP_CA" \
                --embed-certs=true
            rm -f $TEMP_CA
        end
        or return 1

        # Set credentials
        kubectl config --kubeconfig="$KUBECONFIG_FILE" set-credentials $SERVICE_ACCOUNT \
            --token="$TOKEN"
        or return 1

        # Set context
        kubectl config --kubeconfig="$KUBECONFIG_FILE" set-context $CONTEXT_NAME \
            --cluster=$CLUSTER_NAME \
            --user=$SERVICE_ACCOUNT
        or return 1

        # Use context
        kubectl config --kubeconfig="$KUBECONFIG_FILE" use-context $CONTEXT_NAME
        or return 1

        # Secure the file
        chmod 600 $KUBECONFIG_FILE

        return 0
    end

    function renew_token
        echo "Renewing MCP viewer token..."

        # Check if service account exists
        if not kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE &>/dev/null
            echo "Error: Service account not found. Run 'k8s-mcp-setup setup' first."
            return 1
        end

        generate_kubeconfig
        or return 1

        echo ""
        echo "Token renewed successfully!"
        echo "New token expires in $TOKEN_DURATION."
    end

    function check_status
        echo "Checking Kubernetes MCP setup status..."
        echo ""

        set -l all_ok true

        # Check namespace
        echo -n "Namespace '$NAMESPACE': "
        if kubectl get namespace $NAMESPACE &>/dev/null
            set_color green; echo "OK"; set_color normal
        else
            set_color red; echo "NOT FOUND"; set_color normal
            set all_ok false
        end

        # Check service account
        echo -n "Service account '$SERVICE_ACCOUNT': "
        if kubectl get serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE &>/dev/null
            set_color green; echo "OK"; set_color normal
        else
            set_color red; echo "NOT FOUND"; set_color normal
            set all_ok false
        end

        # Check cluster role binding
        echo -n "Cluster role binding 'mcp-viewer-crb': "
        if kubectl get clusterrolebinding mcp-viewer-crb &>/dev/null
            set_color green; echo "OK"; set_color normal
        else
            set_color red; echo "NOT FOUND"; set_color normal
            set all_ok false
        end

        # Check kubeconfig file
        echo -n "Kubeconfig file: "
        if test -f $KUBECONFIG_FILE
            set_color green; echo "OK ($KUBECONFIG_FILE)"; set_color normal
        else
            set_color red; echo "NOT FOUND"; set_color normal
            set all_ok false
        end

        # Test connectivity with MCP kubeconfig
        if test -f $KUBECONFIG_FILE
            echo -n "Cluster connectivity (via MCP kubeconfig): "
            if kubectl --kubeconfig="$KUBECONFIG_FILE" get pods -A &>/dev/null
                set_color green; echo "OK"; set_color normal
            else
                set_color yellow; echo "FAILED (token may be expired, try 'k8s-mcp-setup renew')"; set_color normal
                set all_ok false
            end
        end

        echo ""
        if $all_ok
            set_color green
            echo "All checks passed!"
            set_color normal
        else
            set_color yellow
            echo "Some checks failed. Run 'k8s-mcp-setup setup' to fix."
            set_color normal
            return 1
        end
    end

    function cleanup_mcp
        echo "Cleaning up Kubernetes MCP resources..."
        echo ""

        # Delete cluster role binding
        echo "Removing cluster role binding..."
        kubectl delete clusterrolebinding mcp-viewer-crb --ignore-not-found

        # Delete service account
        echo "Removing service account..."
        kubectl delete serviceaccount $SERVICE_ACCOUNT -n $NAMESPACE --ignore-not-found

        # Delete namespace
        echo "Removing namespace..."
        kubectl delete namespace $NAMESPACE --ignore-not-found

        # Remove kubeconfig
        echo "Removing kubeconfig file..."
        rm -f $KUBECONFIG_FILE

        echo ""
        echo "Cleanup complete!"
    end

    # Main command dispatch
    if test (count $argv) -eq 0
        show_help
        exit 0
    end

    switch $argv[1]
        case setup
            check_kubectl; or exit 1
            setup_mcp
        case renew
            check_kubectl; or exit 1
            renew_token
        case status
            check_kubectl; or exit 1
            check_status
        case cleanup
            check_kubectl; or exit 1
            cleanup_mcp
        case help -h --help
            show_help
        case '*'
            echo "Unknown command: $argv[1]"
            echo "Run 'k8s-mcp-setup help' for usage."
            exit 1
    end
  '';

  # MCP server picker (merge selected servers into a project .mcp.json)
  mcpPick = ''
    #!/usr/bin/env bash
    set -euo pipefail

    mcp_dir="$HOME/.claude/mcp-servers"
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

    if ! command -v jq >/dev/null 2>&1; then
      echo "jq is required but not installed." >&2
      exit 1
    fi

    output=".mcp.json"
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      if ! grep -qE '(^|/)\.mcp\.json$' .gitignore 2>/dev/null; then
        echo "Warning: .gitignore does not include .mcp.json" >&2
      fi
    fi
    if [[ -e "$output" ]]; then
      read -r -p "''${output} exists. Overwrite? [y/N] " reply
      case "$reply" in
        [yY]|[yY][eE][sS]) ;;
        *) echo "Aborted."; exit 1 ;;
      esac
    fi
    tmp="$(mktemp)"
    echo '{"mcpServers":{}}' > "$tmp"

    while IFS= read -r name; do
      shopt -s nullglob
      files=("$mcp_dir/$name"/.mcp*)
      if [[ ''${#files[@]} -eq 0 ]]; then
        echo "No .mcp* files found for $name" >&2
        exit 1
      fi
      if [[ ''${#files[@]} -gt 1 ]]; then
        echo "Multiple .mcp* files found for $name; expected one." >&2
        exit 1
      fi
      tmp2="$(mktemp)"
      jq -s '.[0].mcpServers * .[1].mcpServers | {mcpServers: .}' "$tmp" "''${files[0]}" > "$tmp2"
      mv "$tmp2" "$tmp"
    done <<< "$selected"

    mv "$tmp" "$output"
    echo "Wrote $output"
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

      enableGLM = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable GLM model toggle via Z.AI proxy (fish function 'glm').";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # System packages for MCP server dependencies and LSP servers
    environment.systemPackages = with pkgs; [
      nodejs_24 # Includes npm and npx for MCP servers
      (writeScriptBin "k8s-mcp-setup" k8s-mcp-setup)
      (writeScriptBin "mcp-pick" mcpPick)
      fzf
      jq

      # Language servers for Claude Code intelligence
      gopls # Go language server
      rust-analyzer # Rust language server
    ];

    home-manager.users.${username} = {
      programs = {
        claude-code = {
          enable = true;
          package = pkgs.claude-code;

          # Settings (JSON config)
          settings = {
            cleanupPeriod = 15;
            coAuthor = "";
            includeCoAuthoredBy = false;

            # Permissions - auto-approve common Nix and git operations
            permissions.allow = [
              "Bash(nix flake check:*)"
              "Bash(statix check:*)"
              "Bash(echo:*)"
              "Bash(mkdir:*)"
              "WebFetch(domain:git.sr.ht)"
              "WebFetch(domain:github.com)"
              "WebFetch(domain:githubusercontent.com)"
              "Bash(git add:*)"
              "Bash(git push)"
              "Bash(git commit:*)"
              "Bash(git rm:*)"
              "Bash(git reset:*)"
            ];
          };

          # Memory file (CLAUDE.md - project rules and context)
          memory.text = builtins.readFile ../../../../CLAUDE.md;

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

          # Skills and MCP servers managed through Home Manager options.
          skills.commit = ./skills/commit;
        };

        fish = {
          # GLM toggle function
          functions = lib.mkIf (cfg.enableGLM && zaiApiKey != null) {
            glm = {
              argumentNames = [ "cmd" ];
              body = ''
                switch "$cmd"
                  case on
                    set -gx ANTHROPIC_AUTH_TOKEN "${zaiApiKey}"
                    set -gx ANTHROPIC_BASE_URL "https://api.z.ai/api/anthropic"
                    set -gx API_TIMEOUT_MS "3000000"
                    set -gx ANTHROPIC_DEFAULT_HAIKU_MODEL "glm-5"
                    set -gx ANTHROPIC_DEFAULT_SONNET_MODEL "glm-5"
                    set -gx ANTHROPIC_DEFAULT_OPUS_MODEL "glm-5"
                    echo "GLM mode ON — Claude Code will route through Z.AI"
                  case off
                    set -e ANTHROPIC_AUTH_TOKEN
                    set -e ANTHROPIC_BASE_URL
                    set -e API_TIMEOUT_MS
                    set -e ANTHROPIC_DEFAULT_HAIKU_MODEL
                    set -e ANTHROPIC_DEFAULT_SONNET_MODEL
                    set -e ANTHROPIC_DEFAULT_OPUS_MODEL
                    echo "GLM mode OFF — Claude Code will use Anthropic directly"
                  case status ""
                    if set -q ANTHROPIC_BASE_URL
                      if set -q ANTHROPIC_DEFAULT_HAIKU_MODEL
                        echo "GLM mode: ON (base URL: $ANTHROPIC_BASE_URL, model: $ANTHROPIC_DEFAULT_HAIKU_MODEL)"
                      else
                        echo "GLM mode: ON (base URL: $ANTHROPIC_BASE_URL)"
                      end
                    else
                      echo "GLM mode: OFF (using Anthropic directly)"
                    end
                  case '*'
                    echo "Usage: glm [on|off|status]"
                end
              '';
            };
          };

          # Fish abbreviations
          shellAbbrs = {
            cc = {
              position = "command";
              setCursor = true;
              expansion = "claude -p \"%\"";
            };
          };
        };
      };

      # Preserve per-server files for mcp-pick workflow compatibility.
      home.file = mcpServerFiles;
    };
  };
}
