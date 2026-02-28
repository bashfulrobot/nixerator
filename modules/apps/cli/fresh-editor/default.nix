{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.fresh-editor;
in
{
  options = {
    apps.cli.fresh-editor.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the fresh editor.";
    };
  };

  config = lib.mkIf cfg.enable {
    home-manager.users.${globals.user.name} = {
      # LSP servers and formatters — fresh-editor itself is handled by programs.fresh-editor.package
      home.packages = with pkgs; [
        gopls # Go LSP
        delve # Go debugger
        bash-language-server # Shell script LSP
        nixd # Nix LSP
        nixfmt # Nix formatter
        yaml-language-server # YAML LSP (Kubernetes, Helm charts)
        terraform-ls # Terraform / OpenTofu LSP
      ];

      programs.fresh-editor = {
        enable = true;

        settings = {
          version = 1;
          theme = "high-contrast";

          # Nix manages the package; opt out of in-app update checks
          check_for_updates = false;

          editor = {
            # Line numbers — relative style matches helix
            line_numbers = true;
            relative_line_numbers = true;

            # Default indentation; per-language overrides in languages block
            tab_size = 4;
            auto_indent = true;

            # Keep context lines visible above/below cursor (helix-style scrolloff)
            scroll_offset = 5;

            syntax_highlighting = true;

            # Disable soft wrap for code — prefer horizontal scroll
            line_wrap = false;

            # LSP inlay hints (mirrors helix lsp.display-messages)
            enable_inlay_hints = true;

            # Crash recovery / auto-save checkpoints
            recovery_enabled = true;
            auto_save_interval_secs = 2;
          };

          file_explorer = {
            respect_gitignore = true;
            show_hidden = false;
            show_gitignored = false;
          };

          # Per-language tab size overrides
          languages = {
            nix = { tab_size = 2; };
            yaml = { tab_size = 2; };
            toml = { tab_size = 2; };
            terraform = { tab_size = 2; };
            bash = { tab_size = 2; };
            sh = { tab_size = 2; };
            go = { tab_size = 4; };
          };

          # LSP server bindings for primary use cases
          lsp = {
            go.command = "gopls";

            nix.command = "nixd";

            yaml = {
              command = "yaml-language-server";
              args = [ "--stdio" ];
            };

            bash = {
              command = "bash-language-server";
              args = [ "start" ];
            };

            terraform = {
              command = "terraform-ls";
              args = [ "serve" ];
            };
          };
        };
      };
    };
  };
}
