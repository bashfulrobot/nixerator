_:

{
  apps.gui = {
    # Go rewrite (primary), kept alongside the original Kotlin app (installed
    # as `upsight-kotlin`) for side-by-side comparison.
    upsight.enable = true;
    upsight-kotlin.enable = true;
  };

  apps.cli = {
    # Render Nix-eval secrets locally from 1Password (and push to headless
    # peers via `render-secrets --push`). Gated on 1Password being available.
    render-secrets.enable = true;

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

    # ollama.acceleration = "vulkan";

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

  # Pull from qbert's harmonia cache: LAN first, then tailscale, then the
  # upstream caches declared in modules/system/nix.
  # Disabled: self-hosted caching turned off; only the public substituters
  # in modules/system/nix (plus cache.nixos.org) are used.
  system.qbert-cache.enable = false;

  # Server modules
  server = {
    kvm = {
      enable = true;
      routing = {
        enable = true;
        externalInterface = "wlp0s0f3";
        internalInterfaces = [
          "virbr1"
          "virbr2"
          "virbr3"
          "virbr4"
          "virbr5"
          "virbr6"
          "virbr7"
        ];
        proxyArpInterfaces = [ "wlp0s0f3" ];
      };
    };
  };
}
