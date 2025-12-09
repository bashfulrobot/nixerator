{ lib, config, ... }:

let
  cfg = config.suites.browsers;
in
{
  options = {
    suites.browsers.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable browser suite with various browsers.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Browser applications
    apps.gui = {
      google-chrome.enable = true;
      chromium.enable = false;  # Disabled in favor of Google Chrome
    };
  };
}
