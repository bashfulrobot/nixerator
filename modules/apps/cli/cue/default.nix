{ pkgs, config, lib, ... }:

let
  cfg = config.apps.cli.cue;
in
{
  options = {
    apps.cli.cue.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable CUE configuration language tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      cue # CUE configuration language CLI
      cuetools # CD image utilities for CUE sheets
      cuelsp # CUE language server protocol
    ];
  };
}
