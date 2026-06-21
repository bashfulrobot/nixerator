{ ... }:

{
  # Adopt the Claude work-host archetype (symmetric peer to srv): zellij
  # (no web, no mosh), sshd, and the work launcher. Sessions live on
  # qbert until killed; attach from anywhere on the tailnet via `work`
  # or `ssh qbert zellij attach`.
  archetypes.claudeWorkHost.enable = true;

  apps.cli = {
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
    kvm = {
      enable = true;
      routing = {
        enable = true;
        externalInterface = "enp34s0";
        internalInterfaces = [
          "virbr1"
          "virbr2"
          "virbr3"
          "virbr4"
          "virbr5"
          "virbr6"
          "virbr7"
        ];
        proxyArpInterfaces = [ "ens2" ];
      };
    };
  };
}
