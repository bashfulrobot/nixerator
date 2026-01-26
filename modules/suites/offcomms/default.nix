{
  lib,
  config,
  pkgs,
  ...
}:

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
      obsidian.enable = true;
      signal.enable = true;
    };

    apps.cli = {
      meetsum.enable = true;
      pandoc.enable = true;
    };

    environment.systemPackages = with pkgs; [
      discord-ptb
      morgen
      slack
      todoist-electron
      typora
    ];
  };
}
