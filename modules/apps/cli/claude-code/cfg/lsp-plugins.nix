{ lib }:

let
  # LSP plugins for Claude Code (via ~/.claude/plugins/marketplaces/nix-lsps/)
  # Source: https://github.com/boostvolt/claude-code-lsps
  lspPlugins = {
    bash-language-server = {
      command = "bash-language-server";
      args = [ "start" ];
      extensions = {
        ".sh" = "shellscript";
        ".bash" = "shellscript";
        ".zsh" = "shellscript";
        ".ksh" = "shellscript";
      };
    };
    gopls = {
      command = "gopls";
      extensions = {
        ".go" = "go";
      };
    };
    lua-language-server = {
      command = "lua-language-server";
      extensions = {
        ".lua" = "lua";
      };
    };
    nixd = {
      command = "nixd";
      extensions = {
        ".nix" = "nix";
      };
    };
    rust-analyzer = {
      command = "rust-analyzer";
      extensions = {
        ".rs" = "rust";
      };
    };
    pyright = {
      command = "pyright-langserver";
      args = [ "--stdio" ];
      extensions = {
        ".py" = "python";
        ".pyi" = "python";
      };
    };
    terraform-ls = {
      command = "terraform-ls";
      args = [ "serve" ];
      extensions = {
        ".tf" = "terraform";
        ".tfvars" = "terraform-vars";
      };
    };
    yaml-language-server = {
      command = "yaml-language-server";
      args = [ "--stdio" ];
      extensions = {
        ".yaml" = "yaml";
        ".yml" = "yaml";
      };
    };
    vtsls = {
      command = "vtsls";
      args = [ "--stdio" ];
      extensions = {
        ".ts" = "typescript";
        ".tsx" = "typescriptreact";
        ".js" = "javascript";
        ".jsx" = "javascriptreact";
        ".mjs" = "javascript";
        ".cjs" = "javascript";
      };
    };
    dart-analyzer = {
      command = "dart";
      args = [ "language-server" ];
      extensions = {
        ".dart" = "dart";
      };
    };
  };

  mkLspJson =
    name: cfg:
    let
      langId = builtins.replaceStrings [ "-language-server" "-analyzer" "-ls" ] [ "" "" "" ] name;
    in
    builtins.toJSON {
      "${langId}" = {
        inherit (cfg) command;
        extensionToLanguage = cfg.extensions;
      }
      // lib.optionalAttrs (cfg ? args) { inherit (cfg) args; };
    };

  mkPluginJson =
    name:
    builtins.toJSON {
      inherit name;
      description = "${name} language server";
      version = "1.0.0";
    };

  files = lib.foldl' (
    acc: name:
    let
      cfg = lspPlugins.${name};
      base = ".claude/plugins/marketplaces/nix-lsps/${name}";
    in
    acc
    // {
      "${base}/.lsp.json".text = mkLspJson name cfg;
      "${base}/.claude-plugin/plugin.json".text = mkPluginJson name;
    }
  ) { } (builtins.attrNames lspPlugins);
in
{
  inherit files;
}
