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
    # Development CLI applications
    apps.cli = {
      claude-code.enable = true;
      git.enable = true;
    };

    # Development tools
    environment.systemPackages = with pkgs; [
      just    # Task runner for project commands
      statix  # Nix linter and code quality checker
    ] ++ [
      pkgs.${globals.preferences.editor}  # User's preferred editor
    ];
  };
}
