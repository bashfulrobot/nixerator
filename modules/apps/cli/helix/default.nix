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

    home-manager.users.${username} = {
      programs.helix = {
        enable = true;
        defaultEditor = true;
        package = pkgs.helix;

        extraPackages = with pkgs; [
          nixfmt-rfc-style
          nixd
          statix
          marksman
          gopls
          golangci-lint-langserver
          delve
          yaml-language-server
        ] ++ lib.optional (lib.hasAttr "helix-gpt" pkgs) pkgs."helix-gpt";

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
              name = "nix";
              auto-format = true;
              formatter.command = "${pkgs.nixfmt-rfc-style}/bin/nixfmt";
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
            yaml = {
              command = "yaml-language-server";
              args = [ "--stdio" ];
              scope = "source.yaml";
            };
          };
        };
      };

      home.sessionVariables = { EDITOR = "hx"; };
    };
  };
}

