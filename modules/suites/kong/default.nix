{ lib, config, ... }:

let
  cfg = config.suites.kong;
in
{
  options = {
    suites.kong.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Kong API Gateway suite with documentation and related tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Kong GUI applications
    apps.gui = {
      insomnia.enable = true;
    };

    # Kong web applications
    apps.webapps = {
      calendar.enable = true;
      clari.enable = true;
      kong-docs.enable = true;
      mail.enable = true;
    };
  };
}
