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
    # Enable workstation suites
    suites = {
      core.enable = true;           # Core system infrastructure
      terminal.enable = true;       # Terminal suite
      browsers.enable = true;       # Browser suite
      security.enable = true;       # Security suite
      dev.enable = true;            # Development suite
    };
  };
}

