{
  globals,
  lib,
  pkgs,
  config,
  secrets,
  ...
}:

let
  cfg = config.apps.cli.claude-code;
  kubernetesMcpServer = pkgs.callPackage ./build { };
  homeDir = globals.user.homeDirectory;
  kubeconfigFile = "${homeDir}/.kube/mcp-viewer.kubeconfig";
  context7ApiKey = (secrets.context7 or { }).apiKey or null;
  mcpServers = {
    kubernetes-mcp-server = {
      command = "${kubernetesMcpServer}/bin/kubernetes-mcp-server";
      args = [ "--read-only" ];
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
  }
  // lib.optionalAttrs (context7ApiKey != null) {
    context7 = {
      type = "http";
      url = "https://mcp.context7.com/mcp";
      headers = {
        CONTEXT7_API_KEY = context7ApiKey;
      };
    };
  }
  // lib.optionalAttrs (secrets.kong.kongKonnectPAT or null != null) {
    kong-konnect = {
      type = "http";
      url = "https://us.mcp.konghq.com/";
      headers = {
        Authorization = "Bearer ${secrets.kong.kongKonnectPAT}";
      };
    };
  };
  mkMcpServerJson =
    name: cfg:
    builtins.toJSON {
      mcpServers = {
        "${name}" = cfg;
      };
    };
  mcpServerFiles = lib.mapAttrs' (name: cfg: {
    name = ".claude/mcp-servers/${name}/.mcp.json";
    value = {
      text = mkMcpServerJson name cfg;
    };
  }) mcpServers;

  # Status line script — jq is in PATH via runtimeInputs
  statusLineScript = pkgs.writeShellApplication {
    name = "claude-statusline";
    runtimeInputs = [ pkgs.jq ];
    text = builtins.readFile ./statusline.sh;
  };

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

    };
  };

  config = lib.mkIf cfg.enable {
    # System packages for MCP tooling and LSP servers
    environment.systemPackages = with pkgs; [
      (writeScriptBin "k8s-mcp-setup" k8s-mcp-setup)
      (writeScriptBin "mcp-pick" mcpPick)
      llm-agents.claude-plugins # Plugin & skills manager
      fzf
      jq

      # Language servers for Claude Code intelligence
      gopls # Go language server
      rust-analyzer # Rust language server
    ];

    home-manager.users.${globals.user.name} = {
      home.packages = with pkgs; [
        libnotify # for notify-send in Stop hook
      ];

      programs = {
        claude-code = {
          enable = true;
          package = pkgs.llm-agents.claude-code;

          # Settings (JSON config)
          settings = {
            cleanupPeriodDays = 15;
            coAuthor = "";
            remoteControlEnabled = true;

            # Status line — two-line display with model, git, tokens, cost, duration
            statusLine = {
              type = "command";
              command = "${statusLineScript}/bin/claude-statusline";
            };

            # Permissions - auto-approve common Nix and git operations
            permissions.allow = [
              # Nix operations
              "Bash(nix flake check *)"
              "Bash(nix build *)"
              "Bash(nix run *)"
              "Bash(nix develop *)"
              "Bash(nix fmt)"
              "Bash(nix fmt *)"
              "Bash(statix check *)"
              "Bash(statix fix *)"
              "Bash(deadnix *)"

              # Git operations
              "Bash(git add *)"
              "Bash(git push)"
              "Bash(git push *)"
              "Bash(git commit *)"
              "Bash(git rm *)"
              "Bash(git reset *)"
              "Bash(git status)"
              "Bash(git status *)"
              "Bash(git log *)"
              "Bash(git diff *)"
              "Bash(git stash *)"
              "Bash(git pull)"
              "Bash(git pull *)"
              "Bash(git fetch *)"
              "Bash(git branch *)"
              "Bash(git switch *)"
              "Bash(git checkout *)"

              # Shell utilities
              "Bash(echo *)"
              "Bash(mkdir *)"
              "Bash(cp *)"
              "Bash(mv *)"
              "Bash(touch *)"
              "Bash(chmod *)"

              # File reading & viewing
              "Bash(cat *)"
              "Bash(bat *)"
              "Bash(head *)"
              "Bash(tail *)"
              "Bash(less *)"
              "Bash(wc *)"

              # File & directory discovery
              "Bash(ls)"
              "Bash(ls *)"
              "Bash(tree *)"
              "Bash(find *)"
              "Bash(fd *)"
              "Bash(file *)"
              "Bash(stat *)"
              "Bash(realpath *)"
              "Bash(readlink *)"
              "Bash(du *)"
              "Bash(df *)"

              # Content searching & text processing
              "Bash(grep *)"
              "Bash(rg *)"
              "Bash(ag *)"
              "Bash(sort *)"
              "Bash(uniq *)"
              "Bash(awk *)"
              "Bash(sed *)"
              "Bash(tr *)"
              "Bash(cut *)"
              "Bash(diff *)"
              "Bash(jq *)"
              "Bash(yq *)"
              "Bash(xargs *)"

              # Environment & system info
              "Bash(which *)"
              "Bash(command *)"
              "Bash(type *)"
              "Bash(env)"
              "Bash(env *)"
              "Bash(uname *)"
              "Bash(whoami)"
              "Bash(pwd)"
              "Bash(date *)"
              "Bash(id)"
              "Bash(id *)"
              "Bash(hostname)"
              "Bash(test *)"
              "Bash([ *)"

              # GitHub CLI
              "Bash(gh *)"

              # Dev toolchains (read/query)
              "Bash(go *)"
              "Bash(cargo *)"
              "Bash(rustc *)"
              "Bash(npm *)"
              "Bash(npx *)"
              "Bash(node *)"
              "Bash(python *)"
              "Bash(python3 *)"
              "Bash(pip *)"

              # Nix introspection
              "Bash(nix-store *)"
              "Bash(nix eval *)"
              "Bash(nix path-info *)"
              "Bash(nix search *)"
              "Bash(nix show-derivation *)"
              "Bash(nixos-option *)"

              # Web fetching
              "WebFetch(domain:git.sr.ht)"
              "WebFetch(domain:github.com)"
              "WebFetch(domain:githubusercontent.com)"
              "WebFetch(domain:nixos.org)"
              "WebFetch(domain:search.nixos.org)"
              "WebFetch(domain:nix-community.github.io)"
              "WebFetch(domain:raw.githubusercontent.com)"
              "WebFetch(domain:wiki.nixos.org)"
              "WebFetch(domain:nix.dev)"
              "WebFetch(domain:discourse.nixos.org)"
              "WebFetch(domain:mynixos.com)"
              "WebFetch(domain:hydra.nixos.org)"
              "WebFetch(domain:doc.rust-lang.org)"
              "WebFetch(domain:docs.rs)"
              "WebFetch(domain:crates.io)"
              "WebFetch(domain:pkg.go.dev)"
              "WebFetch(domain:developer.mozilla.org)"
              "WebFetch(domain:docs.python.org)"
              "WebFetch(domain:nodejs.org)"
              "WebFetch(domain:docs.konghq.com)"
              "WebFetch(domain:stackoverflow.com)"
              "WebFetch(domain:docs.github.com)"
              "WebFetch(domain:man7.org)"
            ];

            hooks = {
              # Sync git state on session start (handles syncthing drift)
              SessionStart = [
                {
                  matcher = "startup";
                  hooks = [
                    {
                      type = "command";
                      command = builtins.concatStringsSep " " [
                        "bash"
                        "-c"
                        (lib.escapeShellArg ''
                          git rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
                          branch=$(git rev-parse --abbrev-ref HEAD)
                          git fetch origin 2>/dev/null || exit 0
                          local_only=$(git log "origin/$branch..$branch" --oneline 2>/dev/null)
                          remote_only=$(git log "$branch..origin/$branch" --oneline 2>/dev/null)
                          if [ -n "$local_only" ] && [ -n "$remote_only" ]; then
                            echo "[git-sync] Diverged — local and remote both have commits. Resolve manually."
                          elif [ -n "$remote_only" ]; then
                            git reset "origin/$branch" >/dev/null 2>&1
                            echo "[git-sync] Aligned git state with origin/$branch"
                          elif [ -n "$local_only" ]; then
                            echo "[git-sync] Unpushed local commits on $branch"
                          fi
                        '')
                      ];
                    }
                  ];
                }
              ];

              # Auto-format .nix files after edits (fire-and-forget)
              PostToolUse = [
                {
                  matcher = "Edit|Write|MultiEdit";
                  hooks = [
                    {
                      type = "command";
                      command = builtins.concatStringsSep " " [
                        "bash"
                        "-c"
                        (lib.escapeShellArg ''
                          input=$(cat)
                          file=$(echo "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)
                          [[ "$file" == *.nix ]] || exit 0
                          nix fmt "$file" 2>/dev/null || true
                        '')
                      ];
                      async = true;
                    }
                  ];
                }
              ];

              # Desktop notification when Claude finishes a response
              Stop = [
                {
                  hooks = [
                    {
                      type = "command";
                      command = builtins.concatStringsSep " " [
                        "bash"
                        "-c"
                        (lib.escapeShellArg ''
                          input=$(cat)
                          msg=$(echo "$input" | jq -r '.last_assistant_message // "Done"' 2>/dev/null | head -c 80)
                          notify-send "Claude Code" "$msg" --icon=terminal 2>/dev/null || true
                        '')
                      ];
                    }
                  ];
                }
              ];
            };
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
            devops = builtins.readFile ./agents/devops.md;
          };

          # No global MCP servers — use mcp-pick per-project to avoid
          # bloating every conversation with unused tool schemas.
          mcpServers = { };

          skills.commit = ./skills/commit;
          skills.humanizer = ./skills/humanizer;

          outputStyles.compact = ./output-styles/compact.md;
        };

        fish = {
          functions = {
            # Wrapper that offers to clean up project .mcp.json on exit
            claude = {
              wraps = "claude";
              body = ''
                command claude $argv
                set -l exit_code $status
                if test -f .mcp.json
                    read -P "Remove .mcp.json from this project? [y/N] " confirm
                    if string match -qi 'y*' -- $confirm
                        rm .mcp.json
                        echo "Removed .mcp.json"
                    end
                end
                return $exit_code
              '';
            };

            # Read-only Q&A — pipe-friendly headless helper
            ask = {
              description = "Ask Claude a question (read-only tools, pipe-friendly)";
              body = ''
                set -l prompt (string join " " $argv)
                if not isatty stdin
                  set input (cat)
                  claude -p "$prompt\n\n$input" --allowedTools "Read,Bash,Glob,Grep"
                else
                  claude -p $prompt --allowedTools "Read,Bash,Glob,Grep"
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
