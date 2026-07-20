{
  lib,
  pkgs,
  secrets,
  globals,
  ...
}:

{
  # Import only modules that srv used in nixcfg, plus the cherry-picked
  # Claude Code + zellij stack.
  imports = [
    ../../modules/apps/cli/agent-scan
    ../../modules/apps/cli/agentos
    ../../modules/apps/cli/claude-code
    ../../modules/apps/cli/fish
    ../../modules/apps/cli/gcmt
    ../../modules/apps/cli/gemini-cli
    ../../modules/apps/cli/git
    ../../modules/apps/cli/helix
    ../../modules/apps/cli/media-rename
    ../../modules/apps/cli/render-secrets
    ../../modules/apps/cli/restic
    ../../modules/apps/cli/skillfish
    ../../modules/apps/cli/starship
    ../../modules/apps/cli/superpowers
    ../../modules/apps/cli/tailscale
    # Declares apps.cli.text-polish.rulesFile, which the claude-code module
    # reads unconditionally. Left disabled here: srv is headless, so the
    # SUPER+SHIFT+R keybind (the module's only config) never applies.
    ../../modules/apps/cli/text-polish
    ../../modules/apps/cli/work-launcher
    ../../modules/apps/cli/zellij
    ../../modules/archetypes/claudeWorkHost
    ../../modules/server/incident-investigator
    ../../modules/server/kvm
    ../../modules/server/nfs
    ../../modules/server/postgres
    ../../modules/system/resilient-boot
    ../../modules/system/ssh
  ];

  # Adopts the Claude work-host archetype: zellij + mosh via system.ssh,
  # sshd, work-launcher. Sessions live on srv until killed; attach from
  # anywhere on the tailnet via `work` or `ssh srv zellij attach`.
  archetypes.claudeWorkHost.enable = true;

  # CLI applications (matching nixcfg srv)
  apps.cli = {
    fish.enable = true;
    git.enable = true;
    helix.enable = true;
    media-rename.enable = true;
    # srv renders its own document-backed secrets (feral-arr download-sync key,
    # incus cert, filebot license) via its 1Password CLI, rather than only
    # receiving them by `just push-secrets srv`. Needs a valid SA token on the
    # host; see extras/docs/secrets.md.
    render-secrets.enable = true;
    starship.enable = true;
    tailscale.enable = true;

    # Claude Code stack (cherry-picked from suites/ai for headless srv)
    agent-scan.enable = true;
    agentos.enable = true;
    claude-code = {
      enable = true;
      serverProfile = "minimal";
      # NOTE: headless srv intentionally runs a SMALLER plugin set than the
      # workstation suite (modules/suites/ai/default.nix). It deliberately omits
      # hyperframes (needs ffmpeg + node + puppeteer and a Chromium-family
      # browser at /run/current-system/sw/bin/${globals.preferences.browser},
      # provisioned via suites.browsers on workstations -- srv is headless), the
      # kong CS plugins, impeccable, and the kotlin/pyright/rust LSPs. Only this
      # list's marketplaces get registered + pinned for srv (all built-in here,
      # so none). Two occurrences = below the rule-of-three threshold; do not
      # extract into a shared lib until a third consumer appears.
      plugins = [
        "frontend-design@claude-plugins-official"
        "asana@claude-plugins-official"
        "code-review@claude-plugins-official"
        "context7@claude-plugins-official"
        "github@claude-plugins-official"
        "feature-dev@claude-plugins-official"
        "commit-commands@claude-plugins-official"
        "security-guidance@claude-plugins-official"
        "pr-review-toolkit@claude-plugins-official"
        "atlassian@claude-plugins-official"
        "learning-output-style@claude-plugins-official"
        "slack@claude-plugins-official"
        "gopls-lsp@claude-plugins-official"
        "skill-creator@claude-plugins-official"
        "ralph-loop@claude-plugins-official"
      ];
    };
    gemini-cli.enable = true;
    skillfish.enable = true;
    superpowers.enable = true;
  };

  # Tailscale subnet router: advertise the home LAN so qbert and donkeykong
  # can reach k8s VM IPs (192.168.168.x) via the tailnet when off the
  # physical LAN. Once applied, approve the route in the Tailscale admin
  # console (or via ACL autoApprovers). useRoutingFeatures="server" enables
  # IP forwarding and the firewall bypass; forwarded packets reach VMs
  # directly over br0 (a true bridge, unlike the old Incus macvlan setup,
  # has no sibling-device/policy-routing workaround to worry about).
  services.tailscale = {
    useRoutingFeatures = "server";
    extraSetFlags = [ "--advertise-routes=192.168.168.0/23" ];
  };

  # System modules
  # Note: this is unrelated to the self-hosted netboot.xyz admin UI that
  # used to live at `server.netbootXyz` (archived, unused). This enables the
  # systemd-boot loader's own netboot.xyz menu entry (chainloads netboot.xyz
  # over the network), one of three features under system.resilient-boot.
  system.resilient-boot.enable = true;
  system.ssh.enable = true;
  # ssh-agent is managed by `keychain` (see hosts/srv/home.nix) so it
  # persists across SSH sessions on this headless box. Do NOT also set
  # `programs.ssh.startAgent` — that would spawn a per-session agent
  # and defeat keychain's single-agent model.

  # Server-specific modules
  server = {
    # Virtualisation on srv moved back from Incus to libvirt/KVM (matching
    # qbert's direction): Talos VMs need real QEMU block-device semantics and
    # a working qemu-guest-agent channel that Incus VMs don't provide (system
    # extensions, in-place upgrades, and the agent itself all broke under
    # Incus). darkstar attaches to br0 (see configuration.nix), an existing
    # Linux bridge replacing the former enp3s0 setup. No NAT-network options
    # needed here either way.
    kvm.enable = true;

    postgres = {
      enable = true;
      # Allow connections from the LAN so k8s nodes on 192.168.168.0/23 can
      # reach PostgreSQL. Individual databases and roles are added here as
      # cluster services are deployed; localhost is always trusted for local
      # admin use.
      allowedCIDRs = [ "192.168.168.0/23" ];
    };

    nfs = {
      enable = true;
      exports = {
        spitfire = {
          path = "/exports/spitfire";
          bindMount = "/srv/nfs/spitfire";
          clients = [ "192.168.168.0/23" ];
          # root_squash (default): root on k8s nodes maps to nobody; pods
          # running as non-root UIDs pass through unmapped, so each workload
          # owns its files with its actual UID rather than a shared anonuid.
          squash = "root_squash";
          uid = 1000;
          gid = 100;
        };
        darkstar = {
          path = "/exports/darkstar";
          bindMount = "/srv/nfs/darkstar";
          clients = [ "192.168.168.0/23" ];
          # CSI driver runs as root and creates subdirs under the export root.
          # no_root_squash passes root through so provisioning works.
          squash = "no_root_squash";
          uid = 1000;
          gid = 100;
        };
        jellyfin-media = {
          path = "/exports/jellyfin-media";
          bindMount = "/home/dustin/data-disk/media";
          clients = [ "192.168.168.0/23" ];
          # Jellyfin's pod runs as UID 1000 (fsGroup), matching the on-disk
          # owner already -- this is a static PV pointed straight at
          # existing files, not a CSI provisioner creating subdirs as root,
          # so root_squash (not darkstar's no_root_squash) is correct.
          squash = "root_squash";
          uid = 1000;
          gid = 100;
        };
      };
      additionalPaths = [
        {
          path = "/srv/nfs/restores";
          mode = "0755";
          uid = 1000;
          gid = 100;
        }
      ];
    };

    # Read-only Claude Code investigator for darkstar Grafana alerts (the srv
    # side of homelab's incident-investigator/). Enabled now that the
    # operator-owned prerequisites below are met. The module renders no secrets
    # into the store, so eval always succeeds; a missing prerequisite would show
    # as a failing unit, not an eval error.
    #
    # Prerequisites (see homelab incident-investigator/README.md):
    #   1. Clone homelab on srv at ~/git/homelab (repoDir default).
    #   2. Read-only darkstar kubeconfig at ~/.kube/darkstar-ro (a view-bound
    #      ServiceAccount, not admin).
    #   3. 1Password automation vault, item `incident-investigator`, two fields:
    #      `shared-secret` (a random bearer token you invent, e.g.
    #      `openssl rand -hex 32` -- Grafana sends it, receiver.py checks it) and
    #      `cloudflared-token` (the tunnel's "Get tunnel token" value).
    #      Pushover-api already exists.
    #   4. The cloudflared tunnel (remediator.srvrs.co -> http://localhost:8099,
    #      remotely-managed / Config type Remote, behind Cloudflare Access) is
    #      already created; the token from step 3 drives it. Turn on
    #      `incidentInvestigator.tunnel.enable = true` below to run it.
    #   5. Grafana side (a homelab PR): a GrafanaContactPoint (type webhook) to
    #      https://remediator.srvrs.co with the shared secret as the bearer
    #      token, plus a notification-policy route selecting alerts to auto-
    #      investigate. Same pattern as pushover-dustin.
    incidentInvestigator = {
      enable = true;
      tunnel.enable = true;
      # Serve incident bundles on the tailnet so the RCA Pushover ping links to a
      # phone-readable rca.html (https://srv.goat-cloud.ts.net/incidents/...)
      # instead of an unreadable filesystem path. Tailnet-only, never public.
      publish.enable = true;
    };

  };

  apps.cli.restic = {
    enable = true;
    backup = {
      enable = true;
      secretsProfile = "srv";
      # The ad-hoc ~/docker stack (caddy status page, uptime-kuma) was
      # deprecated and removed once forgejo/jellyfin moved to the k8s cluster,
      # so /srv/nfs is the only remaining backup target on srv.
      backupPaths = [
        "/srv/nfs"
      ];
      restorePath = "/srv/nfs/restores";
      schedule = "*-*-* 03:00:00";
      keepDaily = 7;
      keepWeekly = 4;
      keepMonthly = 12;
      keepYearly = 2;
    };
  };

  # GitHub access token for nix. srv deliberately does NOT import
  # modules/system/nix (that module is tuned for interactive workstations:
  # desktop-responsive max-jobs/cores and the hyprland cachix substituter).
  # All srv needs from it is the token so `nix flake update` (`just qu`) can
  # resolve the PRIVATE bashfulrobot/upsight flake input via the GitHub API
  # (an unauthenticated resolve 404s). Gated on the secret exactly as the
  # system/nix module is; the value comes from secrets.github.accessToken and
  # never enters Nix eval output.
  nix.settings = lib.optionalAttrs ((secrets.github.accessToken or null) != null) {
    access-tokens = "github.com=${secrets.github.accessToken}";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;

  # 1Password CLI. programs._1password also creates ~/.config/op with
  # mode 700 via tmpfiles, which op requires. The SA token is loaded by
  # the fish module from secrets.json. No GUI or polkit needed on headless srv.
  programs._1password = {
    enable = true;
    package = pkgs._1password-cli;
  };
}
