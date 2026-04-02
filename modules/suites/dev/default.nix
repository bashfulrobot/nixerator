{
  lib,
  pkgs,
  config,
  globals,
  ...
}:

let
  cfg = config.suites.dev;
in
{
  options = {
    suites.dev.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable development suite with AI coding assistants and dev tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Development tools
    dev = {
      go.enable = true;
    };

    # Development CLI applications
    apps = {
      cli = {
        amber.enable = true;
        direnv.enable = true;
        # cue: removed
        git.enable = true;
        helix.enable = true;
        lswt.enable = true;
        nix.enable = true;
        nix-search-tv.enable = true;
        shadowenv.enable = true;
        kotlin-lsp.enable = true;
        worktree-flow.enable = true;
      };
      gui = {
        vscode.enable = false;
        vscode.nautilusIntegration = false;
        upsight.enable = true;
        zed.enable = true;
        zed.nautilusIntegration = true;
      };
    };

    # Development tools
    environment.systemPackages =
      with pkgs;
      [
        filezilla # FTP/SFTP client
        just # Task runner for project commands
        statix # Nix linter and code quality checker
        git-cliff # Conventional changelog generator
        jq # JSON processor
        yq-go # YAML processor
        hugo # Static site generator
        envsubst # Environment variable substitution
        sqlite # SQLite CLI client and library
        litecli # User-friendly SQLite CLI with autocomplete and syntax highlighting
        sqlite-utils # CLI tool for manipulating SQLite databases
      ]
      ++ [
        pkgs.${globals.preferences.editor} # User's preferred editor
      ];
  };
}
