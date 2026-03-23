{
  lib,
  pkgs,
  config,
  versions,
  ...
}:

let
  cfg = config.apps.cli.localsend-rs;
  localsend-rs = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.localsend-rs = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Enable localsend-rs CLI for local file/text transfer via LocalSend protocol.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ localsend-rs ];
  };
}
