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
    apps = {
      # Kong CLI applications
      cli = {
        # kong-docs-offline: removed
        deck.enable = true;
        salesforce-cli.enable = true;
      };

      # Kong GUI applications
      gui = {
        insomnia.enable = true;
        # v13 beta side-by-side (separate binary + isolated data dir)
        insomnia.beta.enable = true;
      };

      # Kong web applications
      webapps = {
        calendar.enable = false;
        clari.enable = false;
        kong-docs.enable = false;
        mail.enable = false;
      };
    };
  };
}
