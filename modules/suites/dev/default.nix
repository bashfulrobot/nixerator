{ lib, config, ... }:

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
    };
  };
}
