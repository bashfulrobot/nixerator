{
  lib,
  pkgs,
  config,
  inputs,
  ...
}:

let
  cfg = config.apps.cli.openspec;
in
{
  options = {
    apps.cli.openspec.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable OpenSpec CLI tool.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ inputs.openspec.packages.${pkgs.system}.default ];
  };
}
