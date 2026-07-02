{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.iso-topology;
  isoTopology = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.iso-topology.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable iso-topology: isometric 2.5D architecture diagrams from a text DSL.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ isoTopology ];
  };
}
