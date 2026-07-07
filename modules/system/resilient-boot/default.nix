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

    # SYSTEMD_SULOGIN_FORCE=1 hands out an unauthenticated root shell to
    # anyone who selects this entry from the boot menu (no boot-loader
    # password is set on any host this module targets). Accepted risk: none
    # of srv/donkeykong/qbert expose a network-reachable BMC/IPMI/remote-KVM,
    # so reaching this entry requires physical presence at the machine, which
    # already implies unencrypted-disk access on qbert/srv (no LUKS) and a
    # LUKS passphrase prompt on donkeykong. If this module is ever applied to
    # a host with remote out-of-band console access, gate this specialisation
    # behind a systemd-boot menu password first.
    #
    # rescue.target only requires sysinit.target + rescue.service -- it never
    # reaches boot-complete.target, so systemd-bless-boot.service never runs
    # for this specialisation's own boot entry. Its tries-left counter will
    # therefore always run down to 0 ("bad") after normal use, regardless of
    # whether the rescue boot itself "worked". This is harmless: per
    # systemd-boot(7)'s BOOT COUNTING section, a "bad" entry stays fully
    # manually selectable forever, it's only deprioritized for *automatic*
    # default-entry selection and menu ordering (bad entries sort first, not
    # hidden). Nothing to fix here, just don't be surprised by the rescue
    # entry showing as "bad" after a few uses.
    specialisation.rescue.configuration = {
      system.nixos.tags = [ "rescue-mode" ];
      boot.loader.systemd-boot.sortKey = "o_rescue-mode";
      boot.kernelParams = [
        "rescue"
        "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1"
      ];
    };

    # Bundled as one flag rather than three independent sub-options: all
    # three current consumers (srv, donkeykong, qbert) want all three
    # features identically, and nothing today needs a different `tries`
    # value or a subset. Split this up if a host ever needs to diverge, or if
    # a host with a different physical/console-access trust model than these
    # three (e.g. shared or colocated hardware) adopts this module and needs
    # the rescue specialisation without the other two -- don't build that
    # flexibility speculatively before it's needed.
    boot.loader.systemd-boot = {
      # netboot.xyz's iPXE chainload requires deliberately selecting this
      # menu entry (never an automatic/default choice) and LAN position to
      # intercept, so the exposure is limited to a manual boot on a
      # compromised/hostile network. Acceptable for these hosts' trust model;
      # revisit if this module is ever applied to a host on a shared or
      # untrusted LAN.
      netbootxyz.enable = true;
      bootCounting = {
        enable = true;
        # Matches the nixpkgs default; set explicitly since the option is
        # what this module exists to turn on, and an explicit value survives
        # a future upstream default change unnoticed.
        tries = 3;
      };
    };
  };
}
