{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.hop;
  hop = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.hop.enable = lib.mkEnableOption "hop, a Claude Code profile (account) switcher that wraps the claude CLI";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ hop ];
  };
}
