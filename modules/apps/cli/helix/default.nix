{
  globals,
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.cli.helix;
  kotlin-lsp = pkgs.callPackage ../kotlin-lsp/build { inherit versions; };
  yaml-schema-router = pkgs.callPackage ../yaml-schema-router/build { inherit versions; };
in
{
  options = {
    apps.cli.helix.enable = lib.mkEnableOption "the helix editor";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      helix
    ];

    home-manager.users.${globals.user.name} = {
      programs.fish.shellAliases.vi = "hx";

      programs.helix = {
        enable = true;
        # fresh-editor owns EDITOR/VISUAL and the system-wide default now
        # (see modules/apps/cli/fresh-editor). Flip this back if helix
        # should win instead.
        defaultEditor = false;
        package = pkgs.helix;

        extraPackages = with pkgs; [
          cuelsp
          delve
          golangci-lint-langserver
          gopls
          harper
          markdown-oxide
          marksman
          nixd
          nixfmt
          statix
          kotlin-lsp
          yaml-language-server
          yaml-schema-router
        ];

        settings = lib.mkMerge [
          {
            editor = {
              line-number = "relative";
              bufferline = "multiple";
              soft-wrap.enable = true;
              indent-guides.render = true;
              lsp.display-messages = true;

              cursor-shape = {
                normal = "block";
                insert = "bar";
                select = "underline";
              };

              statusline = {
                left = [
                  "mode"
                  "spinner"
                  "file-name"
                  "file-modification-indicator"
                ];
                center = [ "diagnostics" ];
                right = [
                  "selections"
                  "position"
                  "file-type"
                  "file-encoding"
                ];
              };
            };
          }
        ];

        languages = {
          language = [
            {
              name = "cue";
              auto-format = true;
              language-servers = [ "cuelsp" ];
            }
            {
              name = "nix";
              auto-format = true;
              formatter.command = "${pkgs.nixfmt}/bin/nixfmt";
              language-servers = [
                "nixd"
                "statix"
              ];
            }
            {
              name = "go";
              auto-format = true;
              language-servers = [ "gopls" ];
            }
            {
              name = "kotlin";
              auto-format = true;
              language-servers = [ "kotlin-lsp" ];
            }
            {
              name = "toml";
              auto-format = true;
            }
            {
              name = "yaml";
              language-servers = [
                "yaml"
                "scls"
              ];
            }
            # language-servers lists in helix REPLACE the upstream default
            # (no append). When adding more LSPs later, merge them into
            # these lists or they will silently stop attaching.
            {
              name = "markdown";
              language-servers = [
                "marksman"
                "markdown-oxide"
                "harper-ls"
              ];
            }
            {
              name = "git-commit";
              language-servers = [ "harper-ls" ];
            }
          ];

          language-server = {
            cuelsp = {
              command = "cuelsp";
            };
            kotlin-lsp = {
              command = "${kotlin-lsp}/bin/kotlin-lsp";
            };
            yaml = {
              command = "${yaml-schema-router}/bin/yaml-schema-router";
              args = [
                "--lsp-path"
                "${pkgs.yaml-language-server}/bin/yaml-language-server"
              ];
              scope = "source.yaml";
            };
            harper-ls = {
              command = "${pkgs.harper}/bin/harper-ls";
              args = [ "--stdio" ];
              config.harper-ls.dialect = "Canadian";
            };
          };
        };
      };

    };
  };
}
