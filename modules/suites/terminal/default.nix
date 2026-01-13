{ lib, pkgs, config, ... }:

let
  cfg = config.suites.terminal;
in
{
  options = {
    suites.terminal.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable terminal suite with shell, prompt, and terminal utilities.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Shell and prompt
    apps.cli = {
      fish.enable = true;
      starship.enable = true;
      zoxide.enable = true;
      superfile.enable = true;
    };

    # Terminal utilities - Modern Rust replacements for classic Unix tools
    environment.systemPackages = with pkgs; [
      # Interactive utilities
      gum        # Glamorous shell scripts (prompts, inputs, spinners)
      glow       # Markdown renderer

      # Modern Rust CLI tools
      bat        # cat replacement with syntax highlighting
      dust       # du replacement with tree visualization
      eza        # ls replacement with colors and git integration
      fd         # find replacement with better UX
      ripgrep    # grep replacement (faster)
      tokei      # Code statistics (lines of code counter)
      procs      # ps replacement with colored output
      sd         # sed replacement with simpler syntax
      bottom     # top/htop replacement (system monitor)
      hyperfine  # Command-line benchmarking tool
    ];
  };
}
