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

    # Terminal utilities
    environment.systemPackages = with pkgs; [
      gum
      bat
      glow
    ];
  };
}
