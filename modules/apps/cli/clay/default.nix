{
  lib,
  pkgs,
  config,
  globals,
  versions,
  ...
}:

let
  cfg = config.apps.cli.clay;
  clay = pkgs.callPackage ./build { inherit versions; };
in
{
  options.apps.cli.clay = {
    enable = lib.mkEnableOption "Clay web UI for Claude Code";

    port = lib.mkOption {
      type = lib.types.port;
      default = 2634;
      description = "Port for the Clay server.";
    };
  };

  config = lib.mkIf cfg.enable {
    networking.firewall.allowedTCPPorts = [ cfg.port ];

    home-manager.users.${globals.user.name} = {
      home.packages = [
        clay
        pkgs.mkcert
      ];
    };
  };
}
