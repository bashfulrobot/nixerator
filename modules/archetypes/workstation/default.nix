{ lib, config, ... }:

let
  cfg = config.archetypes.workstation;
in
{
  options = {
    archetypes.workstation.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable workstation archetype with core system infrastructure, browsers, security, and development suites.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable core system infrastructure
    suites.core.enable = true;

    # Enable terminal suite
    suites.terminal.enable = true;

    # Enable browser suite
    suites.browsers.enable = true;

    # Enable security suite
    suites.security.enable = true;

    # Enable development suite
    suites.dev.enable = true;
  };
}

