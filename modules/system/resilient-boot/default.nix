{
  lib,
  config,
  ...
}:

let
  cfg = config.system.resilient-boot;
in
{
  options = {
    system.resilient-boot.enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Enable resilient-boot options for systemd-boot hosts:

        - A `rescue` specialisation that forces `SYSTEMD_SULOGIN_FORCE=1`, so
          sulogin grants a root shell even when root password login is
          disabled, without having to hand-edit kernel params at the boot
          menu.
        - `netboot.xyz` as a systemd-boot menu entry, for live
          installers/rescue utilities.
        - Boot counting: a freshly written boot entry gets a limited number
          of tries before systemd-boot falls back to the last-known-good
          generation. Useful for remote/headless hosts with no console
          access to recover a bad boot by hand.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = config.boot.loader.systemd-boot.enable;
        message = "system.resilient-boot.enable requires boot.loader.systemd-boot.enable = true (netbootxyz and bootCounting are systemd-boot-specific options; this host uses a different bootloader).";
      }
    ];

    specialisation.rescue.configuration = {
      system.nixos.tags = [ "rescue-mode" ];
      boot.loader.systemd-boot.sortKey = "o_rescue-mode";
      boot.kernelParams = [
        "rescue"
        "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1"
      ];
    };

    boot.loader.systemd-boot = {
      netbootxyz.enable = true;
      bootCounting = {
        enable = true;
        tries = 3;
      };
    };
  };
}
