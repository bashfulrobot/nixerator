{ globals, lib, pkgs, config, ... }:

let
  cfg = config.apps.cli.helix;
  username = globals.user.name;
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

    environment.variables = { EDITOR = "hx"; };

    security.sudo.extraConfig = ''
      Defaults env_keep += "EDITOR"
    '';

    home-manager.users.${username} = {
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
          yaml-language-server
        ];

        settings = lib.mkMerge [
          {
            editor = {
              line-number = "relative";
              lsp.display-messages = true;

              cursor-shape = {
                normal = "block";
                insert = "bar";
                select = "underline";
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
              language-servers = [ "nixd" "statix" ];
            }
            {
              name = "toml";
              auto-format = true;
            }
            {
              name = "yaml";
              language-servers = [ "yaml" "scls" ];
            }
          ];

          language-server = {
            cuelsp = {
              command = "cuelsp";
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
