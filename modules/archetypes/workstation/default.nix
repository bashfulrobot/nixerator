{ lib, config, ... }:

let
  cfg = config.archetypes.workstation;
in
{
  options = {
    archetypes.workstation.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable workstation archetype with browser and security suites, and common workstation tools.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable browser suite
    suites.browsers.enable = true;

    # Enable security suite
    suites.security.enable = true;
  };
}
