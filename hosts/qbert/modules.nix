{ globals, ... }:

{
  apps = {
    gui = {
      # Go + Wails + Svelte rewrite of the original Kotlin app.
      upsight.enable = true;
    };

    # Chrome-wrapped shortcut for app.happy.engineering, alongside the
    # apps.cli.happy daemon below -- srv has no graphical session, so this
    # stays qbert-only.
    webapps.happy.enable = true;
  };

  # Adopt the Claude work-host archetype (symmetric peer to srv): zellij +
  # mosh via system.ssh, sshd, and the work launcher. Sessions live on
  # qbert until killed; attach from anywhere on the tailnet via `work`
  # or `ssh qbert zellij attach`.
  archetypes.claudeWorkHost.enable = true;

  # System modules
  system.resilient-boot.enable = true;

  apps.cli = {
    # Opens a Claude Code session in kitty for a Todoist task. The card button
    # comes from server.claudoist on srv. Token: gopass entry
    # automation/claudoist/helper-token.
    claudoist-helper.enable = true;

    # claude-skills owns the declared Claude Code settings keys on this host:
    # one `claude_stack.py apply` call at activation in place of the jq
    # force-merge, the resolved host file read out of the flake input, and
    # ~/.claude/CLAUDE.md plus ~/.claude/statusline.sh written from
    # claude-stack/files/. claude-code itself is enabled by suites.ai; only the
    # switch lives here, because it is flipped one host at a time. Rollback and
    # the per-key ownership table: .claude/docs/claude-stack-apply.md.
    claude-code.stackApply.enable = true;

    # Docker is intentionally left enabled on the workstations (via the
    # workstation archetype's infrastructure suite) for ad-hoc container
    # testing, running alongside Incus. The two were previously kept mutually
    # exclusive out of caution; srv validated that docker + Incus + nftables
    # coexist -- docker's published-port DNAT survives the nftables flip Incus
    # forces on -- so the earlier `docker.enable = lib.mkForce false` is dropped.

    # Daily copy of the secauto gopass entries into the darkstar cluster (the
    # homelab repo's scripts/sync-secauto.sh), so a secret edited here reaches
    # External Secrets Operator without a manual `just workloads::sync-secauto`.
    # qbert is the only host that edits secrets, so it is the one that runs it.
    homelab-secret-sync.enable = true;

    # Render Nix-eval secrets locally from the gopass snapshot (and push to headless
    # peers via `render-secrets --push`).
    render-secrets = {
      enable = true;
      # qbert is a workstation: `render-secrets --from op` restores keys on a new install.
      opSupport = true;
    };

    # aha-fr-report-one / aha-fr-report on demand, plus the daily scheduled
    # run. The timer does not need anyone logged in. The primary user lingers,
    # so the user manager is up from boot, and gws reads its credentials out
    # of ~/.config/gws rather than a session keyring (see modules/system/linger
    # and .claude/docs/user-lingering.md).
    #
    # It sits here rather than on srv because gws is not installed there. gws
    # comes from suites.core, which srv does not enable, and its login is an
    # interactive OAuth browser flow, so the credential store lives on a
    # machine with a browser. gws + wkhtmltopdf already come from the
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
    };

    text-polish.enable = true;
    text-uppercase.enable = true;

    # Mobile/web remote control for Claude Code sessions (happy.engineering).
    # qbert is usually up, so it's a useful pairing target alongside srv.
    happy.enable = true;
    # Laptop that moves networks; restart the daemon once a link is back up.
    happy.restartOnNetworkUp = true;

    # Text expander. See modules/apps/cli/espanso/default.nix for why this
    # goes through the system-level services.espanso rather than Home
    # Manager's -- only the former wires up the CAP_DAC_OVERRIDE wrapper
    # espanso-wayland needs on Hyprland.
    espanso.enable = true;

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

    # Plain-markdown notes under ~/Notes, synced by Syncthing (folder "notes")
    # and read from the phone through Weave on the tailnet. Weave binds to
    # qbert's Tailscale address, so only tailnet peers reach it.
    notes = {
      enable = true;
      keybind = true; # SUPER+CTRL+N opens the fuzzel note launcher
      weave = {
        enable = true;
        listenAddress = globals.hosts.qbert.tailscale_ip;
      };
    };

    # Local LLM server. qbert has the AMD 6800 XT (gfx1030, 16 GB VRAM), which
    # ROCm supports directly with no HSA_OVERRIDE_GFX_VERSION, so the rocm
    # variant is the accelerator (vulkan is the fallback if a ROCm regression
    # ever bites, mirroring voxtype here). Prefetch Qwen3-14B
    # (dense, 9.3 GB Q4_K_M) from the Ollama library; it fits VRAM with room for
    # the 32k context below. loadModels and defaultOpencodeModel both read
    # globals.ai.localCodeModel, so the pulled model and the model opencode
    # requests cannot drift. The module exports
    # OLLAMA_HOST so the ollama CLI reaches this server without endpoint flags,
    # and defaultOpencodeModel wires opencode (from suites.ai) to it as a local
    # OpenAI-compatible provider with no manual setup.
    # opencode is enabled by suites.ai and runs permissive for now. Switch to
    # permissions = "guarded" (with trustedDirs) to bring back the prompts. The
    # secrets agent (gopass and op on the local model) runs through
    # `opencode-secrets`, which keeps its session store on tmpfs.
    opencode = {
      secretsAgent = {
        enable = true;
        model = "ollama/${globals.ai.localCodeModel}";
      };
    };

    ollama = {
      enable = true;
      acceleration = "rocm";
      loadModels = [ globals.ai.localCodeModel ];
      defaultOpencodeModel = globals.ai.localCodeModel;
      # Ollama defaults the context window to a few thousand tokens, which
      # truncates long opencode sessions. 32k is the working size for the
      # 22 GB Qwen3.6 35B-A3B (65% on the GPU, 35% on the CPU).
      # Flash attention is left at ollama's automatic default. The 2026-10-20
      # test (55 tokens/s off, 25 on at 32k) ran on an older ollama. On 0.40 the
      # automatic default decodes at 58 tokens/s at 32k (2026-10-31) and
      # flashAttention = false no longer turns it off. Set flashAttentionOff to
      # rerun the comparison. kvCacheType stays unset: the 32k KV cache is
      # 640 MiB, so q8_0 saves less than one expert layer.
      contextLength = 32768;
      # Keep the model resident: skips the 11 s reload after 5 min idle.
      keepAlive = "-1";
      # srv and the Mac use this server as their opencode model over Tailscale.
      serveOnTailscale = true;
    };
  };

  # Server modules
  server = {
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
