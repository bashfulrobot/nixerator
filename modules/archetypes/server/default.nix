{ lib, config, ... }:

let
  cfg = config.archetypes.server;
in
{
  options = {
    archetypes.server.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable server archetype with core system infrastructure and terminal suite.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Enable server suites
    suites = {
      terminal.enable = true;    # Terminal suite
    };

    # Core system services for servers
    system.ssh.enable = true;
    apps.cli.tailscale.enable = true;
  };
}
