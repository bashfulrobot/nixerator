{
  lib,
  pkgs,
  config,
  ...
}:

let
  cfg = config.apps.gui.kooha;
in
{
  options = {
    apps.gui.kooha.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Kooha screen recorder.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      # keep-sorted start case=no numeric=yes
      kooha # screen recorder
      # keep-sorted end
    ];
  };
}
