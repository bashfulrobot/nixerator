{ globals, ... }:

{
  apps.gui = {
    # Go + Wails + Svelte rewrite of the original Kotlin app.
    upsight.enable = true;
  };

  # Adopt the Claude work-host archetype (symmetric peer to srv): zellij +
  # mosh via system.ssh, sshd, and the work launcher. Sessions live on
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

    # aha-fr-report-one / aha-fr-report on demand, plus a daily user-session
    # timer here on qbert (this workstation is logged into all day, so it
    # reuses the interactive gws session's keyring instead of a separate
    # headless credential on srv). gws + wkhtmltopdf already come from the
    # workstation archetype's suites.core / suites.offcomms.
    aha-fr-report = {
      enable = true;
      schedule = {
        enable = true;
        onCalendar = "*-*-* 09:30:00";
      };
    };

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

    # qbert sits on the home LAN (192.168.168.0/23) over WiFi AND accepts that
    # same subnet as a Tailscale route (srv advertises it in hosts/srv/modules.nix).
    # Without this, the accepted route shadows the direct LAN link and qbert
    # becomes unreachable on its LAN IP (inbound ssh/mosh fail) while Tailscale
    # still works. This prefers the direct LAN route when on-link and falls back
    # to the tailnet when roaming. See the option docs in the tailscale module.
    tailscale.preferLanCidrs = [ "192.168.168.0/23" ];

    syncthing = {
      enable = true;
      host.qbert = true;
    };

    # Local LLM server. qbert has the AMD 6800 XT (gfx1030, 16 GB VRAM), which
    # ROCm supports directly with no HSA_OVERRIDE_GFX_VERSION, so the rocm
    # variant is the accelerator (vulkan is the fallback if a ROCm regression
    # ever bites, mirroring voxtype/whisper-server here). Prefetch Qwen3-14B
    # (dense, 9.3 GB Q4_K_M) from the Ollama library; it fits VRAM with room for
    # the 32k context below. loadModels and defaultGooseModel both read
    # globals.ai.localCodeModel, so the pulled model and the model goose
    # requests cannot drift. The module exports
    # OLLAMA_HOST so goose (from suites.ai) reaches this server without endpoint
    # flags, and defaultGooseModel points goose at it with no goose configure.
    ollama = {
      enable = true;
      acceleration = "rocm";
      loadModels = [ globals.ai.localCodeModel ];
      defaultGooseModel = globals.ai.localCodeModel;
      # Ollama defaults the context window to a few thousand tokens, which
      # truncates long goose sessions well before Qwen3's 32k native limit.
      # 32k is about what a 16 GB card holds with a full-precision KV cache, and
      # flash attention shrinks that cache for free (no quality cost), so it is
      # on by default. To push to 64k+, add kvCacheType = "q8_0" (smaller KV
      # cache, small quality tradeoff) rather than raising contextLength alone.
      contextLength = 32768;
      flashAttention = true;
    };
  };

  # Server modules
  server = {
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
