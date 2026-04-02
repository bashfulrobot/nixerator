{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.kotlin-lsp;
  kotlin-lsp = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.kotlin-lsp.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable kotlin-lsp - JetBrains Kotlin Language Server for editor integration.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ kotlin-lsp ];
  };
}
