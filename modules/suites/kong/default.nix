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
    # Kong web applications
    apps.webapps = {
      kong-docs.enable = true;
    };
  };
}
