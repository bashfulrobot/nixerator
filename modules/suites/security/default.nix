{ lib, config, ... }:

let
  cfg = config.suites.security;
in
{
  options = {
    suites.security.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable security suite for security tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Security applications
    apps.gui.one-password.enable = true;
  };
}
