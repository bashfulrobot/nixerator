{ globals, ... }:

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
    ../../modules/server/kvm
    ../../modules/server/netboot-xyz
    ../../modules/server/nfs
    ../../modules/server/noclaw
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
    noclaw = {
      enable = true;
      # srv routes to the internet via enp3s0 (default gateway lives there);
      # masquerade the container subnet out that interface.
      wanInterface = "enp3s0";
      # Render the scoped 1Password service-account token (op://nixerator/
      # noclaw-op-token/credential) into the container from the nixos-secrets
      # cached file. Provision the value with `just render-secrets`.
      renderOpTokenFromNixosSecrets = true;
    };

    # IPv4-only DDNS: manages the A record for home.bashfulrobot.com.
    # ip6Provider = "none" because srv has no public IPv6; without it the
    # both-stack `domains` option would try (and fail) to manage AAAA.
    cloudflareDdns = {
      enable = true;
      ip4Domains = [ "home.bashfulrobot.com" ];
      ip6Provider = "none";
    };

    kvm = {
      enable = true;
      routing = {
        enable = true;
        externalInterface = "enp3s0";
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

    netbootXyz = {
      enable = true;
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

    nfs = {
      enable = true;
      exports = {
        spitfire = {
          path = "/exports/spitfire";
          bindMount = "/srv/nfs/spitfire";
          exportConfig = "172.16.166.0/24(rw,sync,no_subtree_check,no_root_squash,all_squash,anonuid=1000,anongid=100)";
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

  # Disable docker-proxy on srv: Docker's userspace fallback for published
  # ports would otherwise open a real listening socket on the published host
  # IPs (e.g. 192.168.168.1:3000), which a cross-interface guest packet
  # delivered to INPUT would still hit -- bypassing the nat/PREROUTING
  # RETURN rules installed by server.netbootXyz.blockBridges. With this
  # flag off Docker uses iptables NAT exclusively, so the RETURN rule is
  # actually load-bearing. Scoped to srv because workstations rely on
  # docker-proxy for localhost-to-published-port patterns in dev.
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

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
}
