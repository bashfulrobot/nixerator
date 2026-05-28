{
  pkgs,
  config,
  lib,
  versions,
  ...
}:

let
  cfg = config.apps.cli.yaml-schema-router;
  yaml-schema-router = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.yaml-schema-router.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable yaml-schema-router - content-based JSON schema routing proxy for yaml-language-server.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ yaml-schema-router ];
  };
}
