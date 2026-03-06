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
          base_keymap = "VSCode";
          # vim_mode = true;
          cursor_blink = true;
          cursor_shape = "block";
          format_on_save = "on";
          hard_tabs = false;
          tab_size = 2;
          relative_line_numbers = true;
          show_whitespaces = "all";
          soft_wrap = "none";
          autosave = "on_focus_change";
          colorize_brackets = true;
          project_panel = {
            auto_reveal_entries = true;
          };
          indent_guides = {
            enabled = true;
            coloring = "indent_aware";
          };
          inlay_hints = {
            enabled = true;
          };
          minimap = {
            show = "auto";
            thumb = "always";
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
            max_scroll_history_lines = 16384;
          };
          title_bar = {
            show_branch_icon = true;
            show_branch_name = true;
            show_project_items = true;
          };
          git = {
            gutter = true;
            inline_blame = {
              enabled = true;
            };
          };
          telemetry = {
            diagnostics = false;
            metrics = false;
          };
          features = {
            copilot = false;
            inline_completion_provider = "none";
          };
          assistant = {
            enabled = false;
            version = "2";
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
          wrap_guides = [
            80
            120
          ];
        };
      };
    };
  };
}
