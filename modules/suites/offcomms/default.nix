{ lib, config, pkgs, ... }:

let
  cfg = config.suites.offcomms;
in
{
  options = {
    suites.offcomms.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable communications suite with Signal and other secure messaging applications.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Communication applications
    apps.gui = {
      signal.enable = true;
    };

    apps.cli = {
      meetsum.enable = true;
    };

    environment.systemPackages = with pkgs; [
      discord-ptb
      todoist-electron
    ];
  };
}
