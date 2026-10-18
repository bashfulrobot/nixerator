{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.dnsglobe;
  dnsglobe = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.dnsglobe.enable = lib.mkEnableOption "dnsglobe global DNS propagation checker TUI";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ dnsglobe ];
  };
}
