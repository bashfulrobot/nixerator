{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.sheets;
  sheets = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.sheets.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable sheets terminal spreadsheet TUI for CSV files.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ sheets ];
  };
}
