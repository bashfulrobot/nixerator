{
  inputs,
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.gui.upsight;
  upsight-pkg = inputs.upsight.packages.${pkgs.stdenv.hostPlatform.system}.default;
in
{
  options = {
    apps.gui.upsight.enable = lib.mkEnableOption "Upsight CSM desktop application";
  };

  config = lib.mkIf cfg.enable {

    environment.systemPackages = [
      upsight-pkg
    ];

  };
}
