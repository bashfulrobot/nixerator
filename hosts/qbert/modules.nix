{ globals, ... }:

{
  apps.gui = {
    # Go rewrite (primary), kept alongside the original Kotlin app (installed
    # as `upsight-kotlin`) for side-by-side comparison.
    upsight.enable = true;
    upsight-kotlin.enable = true;
  };

  # Adopt the Claude work-host archetype (symmetric peer to srv): zellij
  # (no web; mosh via system.ssh), sshd, and the work launcher. Sessions live on
  # qbert until killed; attach from anywhere on the tailnet via `work`
  # or `ssh qbert zellij attach`.
  archetypes.claudeWorkHost.enable = true;

  # System modules
  system.resilient-boot.enable = true;

  apps.cli = {
    # Docker is intentionally left enabled on the workstations (via the
    # workstation archetype's infrastructure suite) for ad-hoc container
    # testing, running alongside Incus. The two were previously kept mutually
    # exclusive out of caution; srv validated that docker + Incus + nftables
    # coexist -- docker's published-port DNAT survives the nftables flip Incus
    # forces on -- so the earlier `docker.enable = lib.mkForce false` is dropped.

    # Render Nix-eval secrets locally from 1Password (and push to headless
    # peers via `render-secrets --push`). Gated on 1Password being available.
    render-secrets.enable = true;

    # Apps
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

    text-polish.enable = true;
    text-uppercase.enable = true;

    syncthing = {
      enable = true;
      host.qbert = true;
    };

    # ollama.acceleration = "rocm";
  };

  # Server modules
  server = {
    # Serve qbert's /nix/store as a binary cache for donkeykong (and any
    # future LAN peer). Donkeykong enables the consumer side via
    # system.qbert-cache.enable.
    # Disabled: self-hosted caching turned off (consumer side off on
    # donkeykong too). Flip both back to true to re-enable.
    harmonia = {
      enable = false;
      interfaces = [
        "tailscale0"
        "enp34s0"
      ];
    };

    whisper-server = {
      enable = true;
      vulkan = true;
    };
    # Virtualisation on qbert moved back from Incus to libvirt/KVM: Talos VMs
    # need real QEMU block-device semantics and a working qemu-guest-agent
    # channel that Incus VMs don't provide (system extensions, in-place
    # upgrades, and the agent itself all broke under Incus). qbert is
    # WiFi-connected, so spitfire stays on a libvirt-managed NAT network
    # (bridge/macvtap modes don't work over 802.11 regardless of hypervisor) —
    # trustedBridgePrefix trusts that network's firewall traffic the same way
    # Incus's did.
    kvm = {
      enable = true;
      trustedBridgePrefix = "vbr-";
    };
  };
}
