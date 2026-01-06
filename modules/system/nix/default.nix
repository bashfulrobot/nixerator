{
  lib,
  config,
  ...
}:

let
  cfg = config.system.nix;
in
{
  options = {
    system.nix.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Enable centralized nix system settings including garbage collection, store optimization, and configuration limits.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Automatic garbage collection
    nix.gc = {
      automatic = true;
      dates = "weekly";
      options = "--delete-older-than 14d";
    };

    # Optimize store automatically
    nix.optimise = {
      automatic = true;
      dates = [ "weekly" ];
    };

    # Keep system generations manageable
    boot.loader.systemd-boot.configurationLimit = lib.mkDefault 10;
  };
}
