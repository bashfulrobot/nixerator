{ pkgs
, config
, lib
, versions
, ...
}:

let
  cfg = config.apps.cli.kiyoproctrls;
  kiyoproctrls = pkgs.callPackage ./build { inherit versions; };
in
{
  options = {
    apps.cli.kiyoproctrls.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable kiyoproctrls - Razer Kiyo Pro webcam controller.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ kiyoproctrls ];
  };
}
