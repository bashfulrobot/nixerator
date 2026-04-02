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
in
{
  options = {
    apps.cli.helix.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable the helix editor.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      helix
    ];

    environment.variables = {
      EDITOR = "hx";
    };

    security.sudo.extraConfig = ''
      Defaults env_keep += "EDITOR"
    '';

    home-manager.users.${globals.user.name} = {
      programs.fish.shellAliases.vi = "hx";

      programs.helix = {
        enable = true;
        defaultEditor = true;
        package = pkgs.helix;

        extraPackages = with pkgs; [
          cuelsp
          delve
          golangci-lint-langserver
          gopls
          marksman
          nixd
          nixfmt
          statix
          kotlin-lsp
          yaml-language-server
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
          ];

          language-server = {
            cuelsp = {
              command = "cuelsp";
            };
            kotlin-lsp = {
              command = "${kotlin-lsp}/bin/kotlin-lsp";
            };
            yaml = {
              command = "yaml-language-server";
              args = [ "--stdio" ];
              scope = "source.yaml";
            };
          };
        };
      };

    };
  };
}
