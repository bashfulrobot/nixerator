{ lib, pkgs, config, globals, ... }:

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
      claude-code.enable = true;
      gemini-cli.enable = true;
      git.enable = true;
      lswt.enable = true;
      nix.enable = true;
      nix-search-tv.enable = true;
      codex.enable = true;
    };
      gui = {
        vscode.enable = true;
      };
    };

    # Development tools
    environment.systemPackages = with pkgs; [
      just    # Task runner for project commands
      statix  # Nix linter and code quality checker
      git-cliff  # Conventional changelog generator
    ] ++ [
      pkgs.${globals.preferences.editor}  # User's preferred editor
    ];
  };
}
