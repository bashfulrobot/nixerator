{
  lib,
  secrets,
  globals,
  ...
}:

{
  # Import only modules that srv used in nixcfg, plus the cherry-picked
  # Claude Code + zellij web stack.
  imports = [
    ../../modules/apps/cli/agent-scan
    ../../modules/apps/cli/agentos
    ../../modules/apps/cli/claude-code
    ../../modules/apps/cli/docker
    ../../modules/apps/cli/fish
    ../../modules/apps/cli/gcmt
    ../../modules/apps/cli/gemini-cli
    ../../modules/apps/cli/git
    ../../modules/apps/cli/graymatter
    ../../modules/apps/cli/helix
    ../../modules/apps/cli/restic
    ../../modules/apps/cli/skillfish
    ../../modules/apps/cli/starship
    ../../modules/apps/cli/superpowers
    ../../modules/apps/cli/tailscale
    ../../modules/apps/cli/vscode-server
    ../../modules/apps/cli/work-launcher
    ../../modules/apps/cli/zellij
    ../../modules/archetypes/claudeWorkHost
    # Dynamic DNS for home.bashfulrobot.com (A record only). Token lives in
    # the `nixerator/cloudflare-ddns` 1Password item; enabled below under
    # `server.cloudflareDdns`.
    ../../modules/server/cloudflare-ddns
    ../../modules/server/incus
    ../../modules/server/netboot-xyz
    ../../modules/server/nfs
    ../../modules/server/noclaw
    ../../modules/server/postgres
    ../../modules/system/caddy
    ../../modules/system/ssh
  ];

  # Adopts the Claude work-host archetype: zellij (no web; mosh via system.ssh),
  # sshd, work-launcher. Sessions live on srv until killed; attach from
  # anywhere on the tailnet via `work` or `ssh srv zellij attach`.
  archetypes.claudeWorkHost.enable = true;

  # CLI applications (matching nixcfg srv)
  apps.cli = {
    docker.enable = true;
    fish.enable = true;
    git.enable = true;
    helix.enable = true;
    starship.enable = true;
    tailscale.enable = true;
    vscode-server.enable = false;

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

  # System modules
  system.ssh.enable = true;
  # ssh-agent is managed by `keychain` (see hosts/srv/home.nix) so it
  # persists across SSH sessions on this headless box. Do NOT also set
  # `programs.ssh.startAgent` — that would spawn a per-session agent
  # and defeat keychain's single-agent model.

  # Server-specific modules
  server = {
    # Always-on Claude Code Remote Control session ("noclaw"), contained in a
    # systemd-nspawn container. Moved here from qbert.
    #
    # TEMPORARILY DISABLED for the Incus migration. Incus forces the host
    # firewall onto nftables, and noclaw's masquerade + egress-lockdown rules go
    # in via networking.firewall.extraCommands, which the nftables firewall
    # rejects at build time. noclaw is development-only on srv and not actively
    # used, so it is off during the cutover and gets re-ported to nftables-native
    # (networking.nat + dnsmasq nftset + extraForwardRules) as a fast-follow.
    noclaw = {
      enable = false;
      # srv routes to the internet via enp3s0 (default gateway lives there);
      # masquerade the container subnet out that interface.
      wanInterface = "enp3s0";
      # Render the scoped 1Password service-account token (op://nixerator/
      # noclaw-op-token/credential) into the container from the nixos-secrets
      # cached file. Provision the value with `just render-secrets`.
      renderOpTokenFromNixosSecrets = true;
      # No nightly recycle. `claude remote-control` mints a NEW session id on
      # every process start (no upstream way to reuse one across restarts -- see
      # anthropics/claude-code#29748), so each restart leaves another dead
      # "noclaw" entry in the phone's Code list. The container HOME is already
      # wiped+restaged on every actual restart (reboot/deploy), so the daily
      # context-flush restart bought almost nothing while costing a duplicate
      # entry per day. Off => one durable entry until a real reboot/deploy.
      recycle.enable = false;
    };

    # IPv4-only DDNS: manages the A record for home.bashfulrobot.com.
    # ip6Provider = "none" because srv has no public IPv6; without it the
    # both-stack `domains` option would try (and fail) to manage AAAA.
    cloudflareDdns = {
      enable = true;
      ip4Domains = [ "home.bashfulrobot.com" ];
      ip6Provider = "none";
    };

    # Virtualisation on srv moved from libvirt/KVM to Incus (matching qbert and
    # donkeykong's direction). srv had zero VM domains defined, so there was
    # nothing to migrate; the old server.kvm block (libvirtd + virt-manager +
    # iptables NAT routing for virbr1-7 and proxy ARP on ens2) is retired. Incus
    # brings its own managed NAT bridge and supervises both system containers and
    # QEMU VMs, so the manual routing is gone. Incus also switches the host
    # firewall to nftables (see modules/server/incus/default.nix).
    incus = {
      enable = true;
      ui.enable = true;
      # srv is headless: no desktop launcher (the default suits workstations).
      ui.desktopEntry = false;
      storage.driver = "btrfs";
      # Loop-backed pool image on the nvme root. The 3.6T data-disk is a slow USB
      # disk, so it is deliberately NOT used for VM/container storage.
      storage.size = "100GiB";
      # Clear of the LAN (192.168.168.0/23), the docker bridge (172.17+), and the
      # retired libvirt ranges, so the managed bridge coexists with everything
      # docker is still running.
      network.ipv4Address = "10.100.0.1/24";
      # terraform-talos names each cluster bridge tbr-<cluster>; the default
      # prefix trusts them all via one wildcard firewall rule, so a future prod
      # cluster on srv needs no change here.
      trustedBridgePrefix = "tbr-";
    };

    # TEMPORARILY DISABLED for the Incus migration. blockBridges installs its
    # PREROUTING RETURN rules via networking.firewall.extraCommands, which the
    # nftables firewall (forced on by Incus) rejects at build time. netboot.xyz
    # is development-only on srv and not actively used, so it is off during the
    # cutover and gets re-ported to a native nft prerouting rule (repointed at
    # incusbr0 / tbr-*) as a fast-follow. Options below are retained inert so
    # re-enabling is a one-line flip.
    netbootXyz = {
      enable = false;
      # NB: pairs with `virtualisation.docker.daemon.settings.userland-proxy
      # = false` below. Without that, docker-proxy opens a real userspace
      # listener on `192.168.168.1:3000` that bypasses the PREROUTING RETURN
      # rule installed by `blockBridges`.
      # Bind container ports to specific host IPs. Listener-binding is the
      # primary exposure control on srv because the kvm module's INPUT-
      # accept override neuters per-interface firewall scoping. LAN ports
      # bind to enp3s0; admin UI binds LAN + Tailscale.
      lanAddress = "192.168.168.1";
      adminAddresses = [
        "192.168.168.1"
        globals.hosts.srv.tailscale_ip
      ];
      # Docker's published-port DNAT in nat/PREROUTING does not filter by
      # input interface, so a libvirt guest routing through srv toward
      # 192.168.168.1 would otherwise reach the unauthenticated admin UI.
      # blockBridges installs PREROUTING RETURN rules that bypass Docker's
      # DNAT for traffic arriving on any virbr*, so guest VMs cannot hit
      # the netboot.xyz listeners.
      blockBridges = [ "virbr+" ];
      # Default ports (3000, 8080) collide with the docker-compose stack on
      # srv -- forgejo owns 3000, shiori owns 8080. Move netboot.xyz to free
      # host ports. httpPort only matters once localMirror.enable is set,
      # but we still want a free default so flipping that flag doesn't
      # collide with shiori.
      adminPort = 3030;
      httpPort = 18080;
    };

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

  };

  # Disable docker-proxy on srv: with docker-proxy off, Docker publishes ports
  # through iptables NAT exclusively instead of opening a real userspace
  # listening socket on the published host IPs (e.g. 192.168.168.1:3000). This
  # was originally load-bearing for server.netbootXyz.blockBridges: the userspace
  # listener would otherwise bypass the nat/PREROUTING RETURN rules that keep a
  # cross-interface guest packet from reaching the netboot admin UI.
  #
  # netbootXyz is TEMPORARILY DISABLED for the Incus migration, so blockBridges
  # is not currently installing those rules. This flag stays off regardless: it
  # is srv's current running behaviour (no dataplane change at cutover), it is
  # benign on its own (NAT-only publishing), and it becomes load-bearing again
  # the moment netbootXyz is re-ported and re-enabled. Scoped to srv because
  # workstations rely on docker-proxy for localhost-to-published-port dev flows.
  virtualisation.docker.daemon.settings.userland-proxy = false;

  apps.cli.restic = {
    enable = true;
    backup = {
      enable = true;
      secretsProfile = "srv";
      backupPaths = [ "/srv/nfs" ];
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
  # resolve the PRIVATE bashfulrobot/upsight* flake inputs via the GitHub API
  # (an unauthenticated resolve 404s). Gated on the secret exactly as the
  # system/nix module is; the value comes from secrets.github.accessToken and
  # never enters Nix eval output.
  nix.settings = lib.optionalAttrs ((secrets.github.accessToken or null) != null) {
    access-tokens = "github.com=${secrets.github.accessToken}";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
