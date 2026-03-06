{
  config,
  lib,
  pkgs,
  inputs,
  globals,
  ...
}:
let
  cfg = config.apps.gui.zed;
  system = "x86_64-linux";
in
{
  options = {
    apps.gui.zed.enable = lib.mkEnableOption "the Zed editor (from upstream flake)";
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      programs.zed-editor = {
        enable = true;
        package = inputs.zed-editor.packages.${system}.default;
        installRemoteServer = true;
        extraPackages = with pkgs; [
          # Language servers
          gopls
          golangci-lint-langserver
          marksman
          nixd
          yaml-language-server

          # Formatters and linters
          nixfmt-rfc-style
          statix
        ];
        extensions = [
          # Languages
          "basher"
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
          helix_mode = true;
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
          languages = {
            Go = {
              hard_tabs = true;
              tab_size = 4;
            };
          };
        };
      };
    };
  };
}
