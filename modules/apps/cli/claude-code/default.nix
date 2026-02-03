{ globals, lib, pkgs, config, secrets, ... }:

let
  cfg = config.apps.cli.claude-code;
  username = globals.user.name;
  homeDir = "/home/${username}";
  kubeconfigFile = "${homeDir}/.kube/mcp-viewer.kubeconfig";

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

      enableGSD = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Enable Get Shit Done (GSD) commands for Claude Code.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable Get Shit Done commands if requested
    apps.cli.get-shit-done.enable = cfg.enableGSD;

    # System packages for MCP server dependencies and LSP servers
    environment.systemPackages = with pkgs; [
      nodejs_24 # Includes npm and npx for MCP servers
      (writeScriptBin "k8s-mcp-setup" k8s-mcp-setup)

      # Language servers for Claude Code intelligence
      gopls # Go language server
      rust-analyzer # Rust language server
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

          # Permissions - auto-approve common Nix and git operations
          permissions.allow = [
            "Bash(nix flake check:*)"
            "Bash(statix check:*)"
            "Bash(echo:*)"
            "Bash(mkdir:*)"
            "WebFetch(domain:git.sr.ht)"
            "WebFetch(domain:github.com)"
            "WebFetch(domain:konghq.com)"
            "WebFetch(domain:githubusercontent.com)"
            "Bash(git add:*)"
            "Bash(git push)"
            "Bash(git commit:*)"
            "Bash(git rm:*)"
            "Bash(git reset:*)"
          ];
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
