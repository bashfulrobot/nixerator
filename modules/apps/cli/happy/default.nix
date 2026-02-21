{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.cli.happy;
in
{
  options = {
    apps.cli.happy = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable Happy CLI and happy-mcp tooling.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      pkgs.llm-agents.happy-coder
    ];
  };
}
