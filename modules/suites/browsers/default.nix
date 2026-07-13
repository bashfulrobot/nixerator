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
      # Brave Origin replaces the retired stock-brave module.
      # Disabled on workstations; module left importable for a quick re-enable.
      brave-origin.enable = false;
      google-chrome.enable = true;
      # google-chrome.enableDev = true;
      helium.enable = true;
    };
  };
}
