{
  lib,
  config,
  inputs,
  ...
}:

let
  cfg = config.apps.gui.wayscriber;
in
{
  options = {
    apps.gui.wayscriber.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable Wayscriber real-time screen annotation tool for Wayland.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [
      inputs.wayscriber.packages.x86_64-linux.default
    ];
  };
}
