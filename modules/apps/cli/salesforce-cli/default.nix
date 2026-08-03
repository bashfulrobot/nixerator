{
  config,
  lib,
  pkgs,
  versions,
  ...
}:

let
  cfg = config.apps.cli.salesforce-cli;
  salesforce-cli = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.salesforce-cli.enable = lib.mkEnableOption "Salesforce CLI (sf) for Salesforce development and administration";
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      salesforce-cli
    ];
  };
}
