_:

{
  apps.gui = {
    # Go + Wails + Svelte rewrite of the original Kotlin app.
    upsight.enable = true;
  };

  apps.cli = {
    # Docker is intentionally left enabled on the workstations (via the
    # workstation archetype's infrastructure suite) for ad-hoc container
    # testing, running alongside Incus. The two were previously kept mutually
    # exclusive out of caution; srv validated that docker + Incus + nftables
    # coexist -- docker's published-port DNAT survives the nftables flip Incus
    # forces on -- so the earlier `mkForce false` is dropped.

    # Render Nix-eval secrets locally from 1Password (and push to headless
    # peers via `render-secrets --push`). Gated on 1Password being available.
    render-secrets.enable = true;

    # On-demand aha-fr-report-one / aha-fr-report commands (no schedule here
    # -- qbert's daily user-session timer is the scheduled copy; this just
    # makes the same binary available for ad hoc / Claude-skill-triggered
    # runs). gws + wkhtmltopdf already come from the workstation archetype's
    # suites.core / suites.offcomms.
    aha-fr-report.enable = true;

    # Attach-only: install the `work` fish function so donkeykong can attach
    # to zellij sessions on srv or qbert. Does NOT expose sessions to peers
    # in v1 — donkeykong is a workstation, not a work-host peer. Promotable
    # later by flipping the claudeWorkHost archetype here.
    work-launcher.enable = true;

    # Apps
    text-polish.enable = true;
    text-uppercase.enable = true;

    syncthing = {
      enable = true;
      host.donkeykong = true;
    };

    restic.backup = {
      enable = true;
      secretsProfile = "workstation";
      backupPaths = [
        "/home/dustin/Desktop"
        "/home/dustin/dev"
        "/home/dustin/Documents"
        "/home/dustin/Downloads"
        "/home/dustin/git"
        "/home/dustin/Music"
        "/home/dustin/Pictures"
        "/home/dustin/Videos"
        "/home/dustin/.kube"
        "/home/dustin/.talos"
        "/home/dustin/.config/upsight"
        "/home/dustin/.local/share/upsight"
      ];
      restorePath = "/tmp/restic-restore";
      schedule = "*-*-* 03:00:00";
      keepDaily = 7;
      keepWeekly = 4;
      keepMonthly = 12;
      keepYearly = 2;
    };
  };

  system.resilient-boot.enable = true;

  # Server modules
  server = {
    # Virtualisation on donkeykong moved back from Incus to libvirt/KVM,
    # matching qbert and srv: Talos VMs need real QEMU block-device semantics
    # and a working qemu-guest-agent channel that Incus VMs don't provide
    # (system extensions, in-place upgrades, and the agent itself all broke
    # under Incus). donkeykong is WiFi-connected like qbert, so any future
    # Talos cluster here would stay on a libvirt-managed NAT network
    # (bridge/macvtap modes don't work over 802.11 regardless of hypervisor)
    # — trustedBridgePrefix trusts that network's firewall traffic the same
    # way Incus's did.
    kvm = {
      enable = true;
      trustedBridgePrefix = "vbr-";
    };
  };
}
