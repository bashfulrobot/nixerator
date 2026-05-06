{
  lib,
  config,
  pkgs,
  globals,
  ...
}:

let
  cfg = config.dev.python;
  helixEnabled = config.apps.cli.helix.enable or false;
  zedEnabled = config.apps.gui.zed.enable or false;
in
{
  options = {
    dev.python.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Python tooling with LSP, linting, and formatting.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      python3 # CPython interpreter and stdlib
      uv # Fast package + project + virtualenv manager
      pipx # Install Python apps in isolated venvs
      poetry # Alternate dependency / packaging manager
      ruff # Linter + formatter (replaces black, isort, flake8, pylint)
      basedpyright # Type checker / LSP server
      mypy # Static type checker
      python3Packages.ipython # Enhanced REPL
      python3Packages.pytest # Test runner
      python3Packages.pip # Bootstrapping for venvs that need it
      python3Packages.virtualenv # venv creation helper
    ];

    home-manager.users.${globals.user.name} = lib.mkMerge [
      {
        home.sessionVariables = {
          # Stop pip / uv from writing __pycache__ next to scripts
          PYTHONDONTWRITEBYTECODE = "1";
          # Unbuffered stdout/stderr for interactive scripts
          PYTHONUNBUFFERED = "1";
        };

        # pipx installs binaries here; uv tool installs go here too
        home.sessionPath = [ "$HOME/.local/bin" ];
      }

      # Helix: register basedpyright + ruff as Python language servers, and
      # use ruff for autoformat. Only applies if helix itself is enabled.
      (lib.mkIf helixEnabled {
        programs.helix = {
          extraPackages = with pkgs; [
            basedpyright
            ruff
          ];

          languages = {
            language = [
              {
                name = "python";
                auto-format = true;
                formatter = {
                  command = "ruff";
                  args = [
                    "format"
                    "-"
                  ];
                };
                language-servers = [
                  "basedpyright"
                  "ruff"
                ];
              }
            ];

            language-server = {
              basedpyright = {
                command = "basedpyright-langserver";
                args = [ "--stdio" ];
              };
              ruff = {
                command = "ruff";
                args = [ "server" ];
              };
            };
          };
        };
      })

      # Zed: use Zed's first-party basedpyright + ruff extensions for LSP
      # parity (diagnostics, hover, code actions), but pin both binaries to
      # the Nix-installed versions so we don't rely on Zed's network fetch.
      # Disable the default `pyright` so basedpyright owns type-checking.
      (lib.mkIf zedEnabled {
        programs.zed-editor = {
          extraPackages = with pkgs; [
            basedpyright
            ruff
          ];

          extensions = [
            "basedpyright"
            "ruff"
          ];

          userSettings = {
            lsp = {
              basedpyright.binary.path = "${pkgs.basedpyright}/bin/basedpyright-langserver";
              ruff.binary.path = "${pkgs.ruff}/bin/ruff";
            };

            languages.Python = {
              tab_size = 4;
              format_on_save = "on";
              language_servers = [
                "basedpyright"
                "ruff"
                "!pyright"
              ];
              formatter = [
                {
                  language_server = {
                    name = "ruff";
                  };
                }
              ];
            };
          };
        };
      })
    ];
  };
}
