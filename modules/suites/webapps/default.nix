{ lib, config, ... }:

let
  cfg = config.suites.webapps;
in
{
  options = {
    suites.webapps.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable web applications suite (web-app-hub apps).";
    };
  };

  config = lib.mkIf cfg.enable {
    # Web applications
    apps.webapps = {
      calendar.enable = true;
      clari.enable = true;
      kong-docs.enable = true;
      mail.enable = true;
    };
  };
}
