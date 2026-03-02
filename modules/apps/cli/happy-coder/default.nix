{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.happy-coder;
in
{
  options = {
    apps.cli.happy-coder.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Happy Coder AI coding tool.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ pkgs.llm-agents.happy-coder ];
  };
}
