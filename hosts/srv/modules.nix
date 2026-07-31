{
  lib,
  pkgs,
  secretsLib,
  globals,
  ...
}:

{
  # Import only modules that srv used in nixcfg, plus the cherry-picked
  # Claude Code + zellij stack.
  imports = [
    ../../modules/apps/cli/agent-scan
    ../../modules/apps/cli/antigravity
    ../../modules/apps/cli/claude-code
    ../../modules/apps/cli/fish
    ../../modules/apps/cli/gcmt
    ../../modules/apps/cli/git
    ../../modules/apps/cli/helix
    ../../modules/apps/cli/opencode
    ../../modules/apps/cli/render-secrets
    ../../modules/apps/cli/restic
    ../../modules/apps/cli/skillfish
    ../../modules/apps/cli/starship
    ../../modules/apps/cli/superpowers
    ../../modules/apps/cli/tailscale
    ../../modules/apps/cli/work-launcher
    ../../modules/apps/cli/zellij
    ../../modules/archetypes/claudeWorkHost
    ../../modules/server/incident-investigator
    ../../modules/server/kvm
    ../../modules/server/nfs
    ../../modules/server/node-exporter
    ../../modules/server/postgres
    # Host-wide invariant, not a feature: declares users.users.<name>.linger so
    # systemd.user timers are scheduled from boot. Workstations get it from
    # ../../modules; srv imports by hand, so it needs the path spelled out.
    # lib/mkHost.nix asserts every host reaches it. Import it from exactly one
    # place per host: a second import path is a second module key, which
    # evaluates the module twice and duplicates its After= entry.
    ../../modules/system/linger
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
    # media-rename (dlm/dltv) removed 2026-07-31: manual filebot-based
    # seedbox-pull-and-rename, superseded by the k8s download-sync CronJob +
    # Sonarr/Radarr import pipeline, and its mediaRoot
    # (/home/dustin/data-disk/media) was the other half of the dual-mount
    # that corrupted a directory on the media disk -- see
    # hardware-configuration.nix.
    # opencode CLI agent + its LSP language servers (kotlin-lsp/yaml-schema-router
    # are already built for helix above, so no extra closure). Points at cloud
    # models by default; srv has no local Ollama provider wiring (qbert-only).
    opencode.enable = true;
    # srv renders its own document-backed secrets (feral-arr download-sync key,
    # incus cert, filebot license) via its 1Password CLI, rather than only
    # receiving them by `just push-secrets srv`. Needs a valid SA token on the
    # host; see extras/docs/secrets.md.
    render-secrets.enable = true;
    starship.enable = true;
    tailscale.enable = true;

    # Claude Code stack (cherry-picked from suites/ai for headless srv)
    agent-scan.enable = true;
    antigravity.enable = true;
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
      #
      # It also omits learning-output-style, pr-review-toolkit, feature-dev, and
      # context7 for the same reason the workstation list does. See the comment
      # in modules/suites/ai/default.nix and issue #294 before re-adding any of
      # them here.
      plugins = [
        "frontend-design@claude-plugins-official"
        "code-review@claude-plugins-official"
        "commit-commands@claude-plugins-official"
        "security-guidance@claude-plugins-official"
        "slack@claude-plugins-official"
        "gopls-lsp@claude-plugins-official"
        "skill-creator@claude-plugins-official"
        "ralph-loop@claude-plugins-official"
      ];
    };
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

  # System modules. One `system` attrset rather than three dotted paths
  # scattered through the file, which reads as a repeated key.
  system = {
    # Note: this is unrelated to the self-hosted netboot.xyz admin UI that
    # used to live at `server.netbootXyz` (archived, unused). This enables the
    # systemd-boot loader's own netboot.xyz menu entry (chainloads netboot.xyz
    # over the network), one of three features under system.resilient-boot.
    resilient-boot.enable = true;

    # ssh-agent is managed by `keychain` (see hosts/srv/home.nix) so it
    # persists across SSH sessions on this headless box. Do NOT also set
    # `programs.ssh.startAgent` — that would spawn a per-session agent
    # and defeat keychain's single-agent model.
    ssh.enable = true;

    # Materialises the GitHub access token read by the nix.extraOptions
    # `!include` further down. The runtime dir is created by installValue's
    # own `mkdir -p`; a systemd.tmpfiles rule would not help because tmpfiles
    # is applied by a systemd unit that only runs after activation scripts.
    activationScripts.nixAccessToken = lib.stringAfter [ "etc" ] (
      secretsLib.installValue {
        jq = "${pkgs.jq}/bin/jq";
        secretsFile = secretsLib.file globals;
        path = ".github.accessToken";
        dest = "/run/nixos-secrets/nix-access-tokens.conf";
        mode = "0600";
        prefix = "access-tokens = github.com=";
        suffix = "\n";
      }
    );
  };

  # Server-specific modules
  server = {
    # Virtualisation on srv moved back from Incus to libvirt/KVM (matching
    # qbert's direction): Talos VMs need real QEMU block-device semantics and
    # a working qemu-guest-agent channel that Incus VMs don't provide (system
    # extensions, in-place upgrades, and the agent itself all broke under
    # Incus). darkstar attaches to br0 (see configuration.nix), an existing
    # Linux bridge replacing the former enp3s0 setup. No NAT-network options
    # needed here either way.
    kvm = {
      enable = true;
      # Disable idle vCPU halt-polling on this hypervisor. The 200us kernel
      # default makes idle vCPUs busy-poll before scheduling out; with 14
      # vCPUs overcommitted on 8 cores across 5 always-on Talos guests, that
      # polling burns host CPU and heat the guests never account as work. 0
      # turns it off; fall back to 50000 (50us) if guest wakeup latency
      # regresses. Applies on the next reboot (kvm stays pinned while VMs
      # run); write /sys/module/kvm/parameters/halt_poll_ns for a live change.
      haltPollNs = 0;
    };

    postgres = {
      enable = true;
      # Allow connections from the LAN so k8s nodes on 192.168.168.0/23 can
      # reach PostgreSQL. Individual databases and roles are added here as
      # cluster services are deployed; localhost is always trusted for local
      # admin use.
      allowedCIDRs = [ "192.168.168.0/23" ];
    };

    # srv hosts the darkstar cluster but was not itself in Grafana: the only
    # node-exporters running were the ones inside the guests, so the hypervisor
    # underneath them reported nothing. Alloy scrapes this from the cluster over
    # br0, which carries both 192.168.168.1 and 192.168.169.200 out of the same
    # /23, so the k8s subnet is the source range.
    nodeExporter = {
      enable = true;
      openFirewallFrom = [ "192.168.168.0/23" ];
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
        # jellyfin-media (path /exports/jellyfin-media, bindMount
        # /home/dustin/data-disk/media) removed 2026-07-31: stale since issue
        # #180 retired NFS from darkstar (zero active NFS clients verified on
        # :2049) and it kept srv mounting /dev/sda1 read-write at the same
        # time the disk is raw-passthrough-mounted read-write inside the
        # darkstar-wk01 Talos guest. That dual mount corrupted a directory
        # btree on it (EXT4-fs error, inode 84279965). The disk is guest-owned
        # only now.
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
  # system/nix module is. The token is materialised at system activation into a
  # root-only 0600 file and pulled in via nix.conf `!include` (read by the nix
  # daemon at runtime), so it never enters the world-readable /etc/nix/nix.conf
  # or the store (issue #265). `!include` no-ops when the file is absent.
  # The file this includes is written by system.activationScripts.nixAccessToken
  # in the system block above.
  nix.extraOptions = ''
    !include /run/nixos-secrets/nix-access-tokens.conf
  '';

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
