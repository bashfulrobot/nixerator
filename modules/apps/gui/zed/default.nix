{
  config,
  lib,
  pkgs,
  globals,
  ...
}:
let
  cfg = config.apps.gui.zed;
in
{
  options = {
    apps.gui.zed.enable = lib.mkEnableOption "the Zed editor";

    apps.gui.zed.nautilusIntegration = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Add 'Open in Zed' to Nautilus right-click context menu.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      home.file.".local/share/nautilus/scripts/Open in Zed" = lib.mkIf cfg.nautilusIntegration {
        executable = true;
        text = ''
          #!/bin/sh
          for path in $NAUTILUS_SCRIPT_SELECTED_FILE_PATHS; do
            if [ -d "$path" ]; then
              zeditor --new "$path" &
            else
              zeditor "$path" &
            fi
          done
        '';
      };

      programs.zed-editor = {
        enable = true;
        package = pkgs.zed-editor;
        installRemoteServer = true;
        extraPackages = with pkgs; [
          # Language servers
          ansible-language-server
          bash-language-server
          dockerfile-language-server
          docker-compose-language-service
          fish-lsp
          gopls
          golangci-lint-langserver
          kotlin-language-server
          helm-ls
          markdown-oxide
          marksman
          nil
          nixd
          rust-analyzer
          taplo
          terraform-ls
          vscode-langservers-extracted # JSON/HTML/CSS/ESLint
          yaml-language-server

          # Formatters and linters
          nixfmt
          statix
        ];
        extensions = [
          # Languages
          "basher"
          "kotlin"
          "dockerfile"
          "fish"
          "golangci-lint"
          "gotmpl"
          "nix"
          "rust"
          "toml"
          "yaml"

          # IaC and DevOps
          "ansible"
          "docker-compose"
          "helm"
          "kubectl"
          "opentofu"
          "proto"
          "terraform"

          # Markup and docs
          "markdown-oxide"

          # Task runners and env
          "env"
          "just"
          "shadowenv"

          # File types and utilities
          "json"
          "color-highlight"
          "comment"
          "dependi"
          "desktop"
          "editorconfig"
          "git-firefly"
          "ini"
          "make"
          "rainbow-csv"
          "xml"
        ];
        userSettings = {
          auto_update = false;
          autosave = "on_focus_change";
          base_keymap = "VSCode";
          colorize_brackets = true;
          cursor_blink = true;
          cursor_shape = "block";
          format_on_save = "on";
          hard_tabs = false;
          helix_mode = false;
          relative_line_numbers = "enabled";
          show_whitespaces = "all";
          show_wrap_guides = true;
          soft_wrap = "editor_width";
          tab_size = 2;
          use_smartcase_search = true;
          when_closing_with_no_tabs = "platform_default";
          wrap_guides = [
            80
            120
          ];

          search = {
            center_on_match = true;
            case_sensitive = false;
          };
          prettier = {
            allowed = false;
          };
          icon_theme = {
            mode = "system";
            light = "Zed (Default)";
            dark = "Zed (Default)";
          };
          agent_servers.claude-acp = {
            type = "registry";
          };
          session = {
            trust_all_worktrees = true;
          };
          agent = {
            enabled = true;
            default_profile = "plan";
          };
          show_inline_completions = false;
          inline_completion_provider = "none";
          edit_predictions = {
            provider = "none";
          };
          features = {
            copilot = false;
          };
          telemetry = {
            diagnostics = false;
            metrics = false;
          };
          git = {
            gutter = true;
            inline_blame = {
              enabled = true;
              show_commit_summary = true;
            };
          };
          indent_guides = {
            enabled = true;
            coloring = "indent_aware";
            background_coloring = "indent_aware";
          };
          inlay_hints = {
            enabled = true;
          };
          minimap = {
            show = "auto";
            thumb = "always";
          };
          project_panel = {
            auto_reveal_entries = true;
          };
          tabs = {
            close_position = "right";
            file_icons = true;
            git_status = true;
            show_close_button = "hover";
            show_diagnostics = "all";
          };
          terminal = {
            blinking = "on";
            copy_on_select = true;
            cursor_shape = "block";
            max_scroll_history_lines = 60000;
          };
          title_bar = {
            show_branch_icon = true;
            show_branch_name = true;
            show_project_items = true;
          };
          node = {
            ignore_system_version = true;
            path = "${pkgs.nodejs_22}/bin/node";
            npm_path = "${pkgs.nodejs_22}/bin/npm";
          };
          lsp = {
            nil = {
              binary = {
                path = "${pkgs.nil}/bin/nil";
              };
            };
            nixd = {
              binary = {
                path = "${pkgs.nixd}/bin/nixd";
              };
            };
            rust-analyzer = {
              binary = {
                path = "${pkgs.rust-analyzer}/bin/rust-analyzer";
              };
            };
            terraform-ls = {
              binary = {
                path = "${pkgs.terraform-ls}/bin/terraform-ls";
              };
            };
            gopls = {
              binary = {
                path = "${pkgs.gopls}/bin/gopls";
              };
            };
            taplo = {
              binary = {
                path = "${pkgs.taplo}/bin/taplo";
              };
            };
            yaml-language-server = {
              binary = {
                path = "${pkgs.yaml-language-server}/bin/yaml-language-server";
              };
            };
            markdown-oxide = {
              binary = {
                path = "${pkgs.markdown-oxide}/bin/markdown-oxide";
              };
            };
            kotlin-language-server = {
              binary = {
                path = "${pkgs.kotlin-language-server}/bin/kotlin-language-server";
              };
            };
            helm-ls = {
              binary = {
                path = "${pkgs.helm-ls}/bin/helm_ls";
              };
            };
          };
          languages = {
            Go = {
              hard_tabs = true;
              tab_size = 4;
            };
          };
        };
      };
      programs.fish.functions = {
        re = {
          description = "Remote edit: open Zed on a remote project via SSH";
          body = ''
            set -l project
            if test (count $argv) -gt 0
              set project $argv[1]
            else
              set project (printf '%s\n' ${
                lib.concatMapStringsSep " " (p: "'${p}'") globals.remoteEdit.projects
              } | fzf --header="Select remote project")
            end
            if test -z "$project"
              return 1
            end
            zed "ssh://${globals.remoteEdit.user}@${globals.remoteEdit.host}/$project"
          '';
        };
      };
    };
  };
}
